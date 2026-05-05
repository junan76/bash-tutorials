# 第 6 章：进程、并发、进程替换

> 对应实验：`exercises/06-processes/` —— 你将为 `bkp` 实现 `lib/parallel.sh`（受限并发的 job 运行器）和 `lib/diff.sh`（两份 manifest 的差异比较）。
> 项目背景见 [Capstone：`bkp`](../capstone.md)。

## 学习目标

完成本章后，你应该能够：

- 解释 bash 视角下"进程"的生命周期：fork → exec → wait → exit code
- 用 `&` 把命令放入后台，用 `$!` 拿到子进程 pid
- 用 `wait` / `wait -n` / `wait -n -p var` 协调多个子进程
- 写一个**受限并发**的 worker pool，控制同时运行的 job 数量
- 用进程替换 `<(...)` / `>(...)` 把命令"伪装成文件"
- 解释为什么 `cmd1 | cmd2` 的右半边在子 shell 里跑、它的赋值出不来

## 6.1 进程模型一分钟回顾

bash 启一条命令的内部动作：

1. **fork()** —— 当前 shell 复制一份子进程
2. **exec()** —— 子进程把自己换成目标程序的内存映像
3. 父进程通常 **wait()** —— 阻塞等子进程结束，拿它的退出码
4. 子进程 **exit(N)** —— `N` 通过 wait 系统调用回到父进程，就是 `$?`

`echo hello` 是这条流水线一秒钟跑完的特例。**后台**（`&`）改的就是第 3 步：父进程不 wait，立刻继续；子进程独立跑下去：

```bash
sleep 5 &        # 子进程在背景跑
echo "pid=$!"    # $! = 最近一个后台进程的 pid
echo "我先打印"
wait             # 显式等所有后台子进程结束
```

`$!` 只在"刚刚 `&` 启动后"的那一行有效——再启一个 `&`，`$!` 就指向新的那个。要长期保留就立刻拷贝到自己的变量。

## 6.2 退出码的真相

每个进程退出时给父进程一个 8-bit 整数（0–255）。约定：

| 退出码 | 含义                   |
| ------ | ---------------------- |
| 0      | 成功                   |
| 1      | 通用失败               |
| 2      | 用法错误（习惯）       |
| 126    | 找到了但不可执行       |
| 127    | command not found      |
| 130    | 被 SIGINT（Ctrl-C）杀  |
| 137    | 被 SIGKILL 杀（128+9） |
| 143    | 被 SIGTERM 杀（128+15）|

**信号 → 退出码：`128 + signum`**。这就是为什么 `kill -9` 后 `$? = 137`。`bkp` 看到子 job 137 应当当作"被外部终止"，区别于业务失败。

`set -e` 看的就是 `$?`：任何"非 0 且没被显式处理"的命令都触发立即退出。"显式处理"包括 `if cmd; then`、`cmd || true`、`cmd && other`、`!cmd` 等。

## 6.3 `wait` 家族

```bash
wait              # 等所有子进程
wait <pid>        # 等指定 pid，$? 是它的退出码
wait -n           # 等任意一个子进程结束（bash 4.3+）
wait -n -p var    # bash 5.1+：把刚结束那个的 pid 写进 $var
```

最有用的是 `wait -n -p`——本章 `parallel_run` 的核心。worker pool 的工作循环长这样：

```
while 还有 job 要做:
    while 在跑的少于 max_jobs 且还有 job 没启动:
        启动下一个 job in background
    wait -n -p donepid       # 阻塞，直到任意一个跑完
    根据 donepid 找到对应 job，登记它的退出码
```

bash 5.0 之前没有 `-p`，得自己用映射表 + `kill -0 pid` 探活——非常烦。本章解法假定 5.1+。

### 捕获子进程的退出码：包一层子 shell

`wait -n -p donepid` 之后，`$?` 就是那个子进程的退出码——但只能取一次，下一条命令的 `$?` 就覆盖它了。如果你要"启 N 个 job、按完成顺序逐个登记"，最稳的做法是**让每个子进程把自己的 rc 写到独立文件里**：

```bash
( bash -c "$cmd"; echo $? > "$tmpdir/$i.rc" ) &
pid_to_idx[$!]=$i
```

外层 `( ... )` 起一个子 shell：里面 `bash -c "$cmd"` 跑命令、`echo $?` 把它的退出码写文件。`&` 把整个**子 shell**放后台。`$!` 拿到的就是这个子 shell 的 pid，跟将来 `wait -n -p` 拿到的对得上。

`tmpdir` 是临时目录（`mktemp -d`），最后 `rm -rf` 清理。**这个 tmpdir 是 worker pool 的核心数据结构**——所有"哪个 job 跑完了、退出码是多少"的状态都在里面。

### `(( i++ ))` 的暗坑

写 `if (( rc != 0 )); then any_failed=1; fi` 而不是 `(( rc != 0 )) && any_failed=1`，否则 `(( 0 ))` 自身返回 1，`set -e` 直接把脚本干掉。

同理 `(( bad++ ))` 在 `bad=0` 时返回 1（自增前的旧值）。**算术上下文里只要表达式结果为 0，整条语句的退出码就是 1**。规避方式：

```bash
bad=$((bad + 1))           # 永远 rc=0
((bad += 1)) || true       # 也可以但啰嗦
```

## 6.4 受限并发：为什么不能"全开"

`bkp run --all --jobs=N` 要并发处理 N 个备份源。直接全部 `&` 启动会出问题：

- 上百个源同时启动 → 上百个 sha256sum 一起冲 IO
- 每个 source 自己也要起 sha256 子进程，进程数爆炸
- 系统盘吞吐被打满，最坏情况主机 IO hang

**worker pool**：控制同时存活的子进程数量到 N。一个跑完、立刻替补一个新的。本章 `parallel_run` 就是这个：

```
parallel_run <max>
  stdin: 一行一个 job，TAB 分隔 <name>\t<bash_command>
  stdout: 每个 job 跑完打一行 <name>\t<rc>（**完成顺序**，不是输入顺序）
  rc: 任意 job 失败 → 1；全部 0 → 0
```

完成顺序而非输入顺序——这是并发原语的本性。如果调用方需要按输入顺序输出，就得在外面再排一层。

## 6.5 进程替换 `<(...)` / `>(...)`

进程替换让你**把命令的 stdout/stdin 伪装成一个文件路径**。语法：

| 语法       | 行为                                          |
| ---------- | --------------------------------------------- |
| `<(cmd)`   | 启动 cmd，给一个文件路径，**读它**等于读 cmd stdout |
| `>(cmd)`   | 启动 cmd，给一个文件路径，**写它**等于写 cmd stdin  |

这个"文件路径"在 Linux 上其实是 `/dev/fd/63` 之类的 fd 别名。

最经典的用法：**对比两个命令的输出**——而不需要先把它们落到磁盘临时文件：

```bash
diff <(sort a.txt) <(sort b.txt)
```

`diff` 接受两个文件参数。`<(sort a.txt)` 在背景启动 `sort a.txt`，把它的 stdout 接到一个匿名 fd，把 fd 路径作为参数传给 `diff`。`diff` 像读普通文件一样读 sort 的输出。两个 sort 真的同时在跑——这是免费得来的并发。

本章 `bkp diff` 在真实使用时长这样：

```bash
manifest_diff \
    <(manifest_build_from_snapshot snap-2026-05-01) \
    <(manifest_build_from_snapshot snap-2026-05-08)
```

`manifest_diff` 自己只关心"两个 manifest 文件路径"。进程替换让我们把"manifest 是从快照现场算出来的"这个事实藏起来——`manifest_diff` 不必知道。**接口和实现的解耦，就是靠这种语法糖落到地上的。**

### `>(...)` 的常见落点：tee 给多个下游

```bash
sha256sum file | tee >(send_to_log) >(notify_oncall) > /dev/null
```

`tee` 把 stdin 同时复制给所有参数（"参数"在这里是进程替换返回的 fd 路径）。

### 进程替换 ≠ 管道

```bash
cmd1 | cmd2          # cmd2 在子 shell 跑，cmd2 里的 var=... 出不来
cmd2 < <(cmd1)       # cmd2 在主 shell 跑，赋值留下来
```

当你需要 `while read line; do count=$((count+1)); done` 这种"循环里改变量"的场景，**绝不要**用 `cmd | while`，要用 `while ... < <(cmd)`。

## 6.6 `trap` 在并发场景下的价值

ch4 引入了 `trap` 处理 lockfile 释放。多子进程场景下 trap 更重要：脚本被 Ctrl-C 时，**子进程不会自动死**，你得在 trap 里 `kill` 它们：

```bash
cleanup() {
    for pid in "${active_pids[@]}"; do
        kill "$pid" 2>/dev/null
    done
    rm -rf "$tmpdir"
}
trap cleanup EXIT INT TERM
```

`bkp` 真正落地时就是这种结构——主程序起一组 worker、用 trap 保证"无论怎么死都不留垃圾"。本章 `parallel_run` 在结尾显式 `rm -rf "$tmpdir"`、不挂 trap，是为了让函数实现简单；实战脚本应该挂 trap。

## 常见坑速查

!!! danger "新手常见坑"
    1. **`cmd &; pid=$!`** 后又起一个 `cmd2 &`——`$!` 已经变成 cmd2 的 pid，cmd 的丢了
    2. **`cmd1 | while read; do count=$((count+1)); done; echo $count`**——子 shell，count 出不来
    3. **`(( count++ ))` 在 `count=0` 时**触发 `set -e`
    4. **`wait -n` 后取 `$?` 拿到的是哪个子进程的？**——bash 不告诉你；只有 `wait -n -p var` 才给 pid
    5. **后台子进程不接 stdin**——它继承父进程的 stdin，如果父在等 read，多个子进程争抢，乱
    6. **进程替换在子 shell 里，访问外部变量是只读快照**——不要指望 `>(...)` 改你的关联数组

---

## 实验：`bkp` 的 parallel + diff 模块

```
exercises/06-processes/starter/lib/
  parallel.sh   # parallel_run
  diff.sh       # manifest_diff
```

这一章把 ch5 写好的 `manifest` 升级成"能并发地多源备份、并且能算 diff 的工具"。两个文件互相独立，但都为更后面的 `bkp run --all` 和 `bkp diff` 子命令服务。

### 函数契约

| 函数                                | 干什么                                                 |
| ----------------------------------- | ------------------------------------------------------ |
| `parallel_run <max_jobs>`           | stdin 读 `<name>\t<cmd>`；最多 max_jobs 并发；按完成顺序往 stdout 打 `<name>\t<rc>`；任意 job 失败则 rc=1 |
| `manifest_diff <old> <new>`         | 比对两份 manifest，打 `+ path` / `- path` / `M path`，按 path 字典序排序；rc=0 |

### 硬性要求

1. `parallel_run` 严格遵守并发上限——给定 `max=2`，任何瞬间在跑的子进程数 ≤ 2
2. `parallel_run` 输出按"完成顺序"，不是输入顺序——并发的本性
3. `manifest_diff` 的输出按 **path 字典序**排序（不是变更类型）
4. `manifest_diff` 即使发现差异也返回 rc=0——"差异本身不是错误"

### 提示

- 启动 job：`( bash -c "${cmds[i]}"; echo $? > "$tmpdir/$i.rc" ) &; pid_to_idx[$!]=$i`
- 等下一个：`wait -n -p donepid`，然后 `idx=${pid_to_idx[$donepid]}`，`unset 'pid_to_idx[$donepid]'`
- 关联数组存在性检查：`[[ -n ${arr[$k]+set} ]]`（`+set` 是个标准的存在性 idiom）
- 用 `printf '...' | sort -k2` 做排序，避免在算法里手写排序逻辑
- 计数器：`finished=$((finished + 1))`，**不要** `(( finished++ ))`

### 跑测试

```bash
cd exercises/06-processes
$EDITOR starter/lib/parallel.sh starter/lib/diff.sh
make grade
```

### 评分项

13 个测试 / 21 分，覆盖：

- `parallel_run`：单 job、失败传播、空 stdin、跑完所有 job、并发提速、严格遵守上限、max>n 的边界
- `manifest_diff`：相同、纯新增、纯删除、纯修改、综合排序、与进程替换组合

其中"严格遵守上限"用一个 flock + 计数器的 job 体来逼出真正的并发峰值；"并发提速"用墙钟时间证明 parallelism 真的在起作用。

---

## 健壮性渐进：本章用足前面四件套

| Ch  | 引入                          |
| --- | ----------------------------- |
| 1   | `set -e`                      |
| 2   | `set -u`                      |
| 3   | `nullglob`                    |
| 4   | `trap` + `local`              |
| 5   | `set -o pipefail`             |
| **6** | **真正"用起"前面引入的全套** ← 本章 |
| 7   | `shellcheck`                  |
| 8   | 幂等 + 集成测试                |

并发是前面所有健壮性约束的"考试场"。`set -e` 让单个 job 出错立即可见；`pipefail` 让 job 内部的管道不悄悄吞错；`trap` 让 Ctrl-C 不留下僵尸子进程；`local` 让 `parallel_run` 的内部状态不污染主程序——本章不引入新的 `set` 选项，但前面的每一个都开始真正"赚回成本"。

---

## 延伸阅读

- `man bash`：**JOB CONTROL**、**SHELL BUILTIN COMMANDS** 中的 `wait`、`Process Substitution`
- [BashGuide: Job Control](https://mywiki.wooledge.org/BashGuide/JobsAndProcesses)
- [BashFAQ #003](https://mywiki.wooledge.org/BashFAQ/003) —— 后台进程 + `$!` 的常见误用
- Stevens, *Advanced Programming in the UNIX Environment*, 第 8 章（进程控制；进阶）
