# 第 7 章：调试与命令行参数解析

> 对应实验：`exercises/07-debug-cli/` —— 你将为 `bkp` 实现 `lib/cli.sh`，包含三件事：调试开关 `enable_debug`、长选项解析 `parse_args`、子命令调度 `dispatch`。
> 项目背景见 [Capstone：`bkp`](../capstone.md)。

## 学习目标

完成本章后，你应该能够：

- 用 `bash -x` 给一个不老实的脚本加观察点
- 自定义 `PS4` 让 trace 行携带"文件:行号:函数"等定位信息
- 在脚本里用 `set -x` / `set +x` 局部开关 trace
- 用 `getopts` 处理短选项；用 case 模式手写长选项解析（包括 `--key=val` / `--key val` / `--`）
- 写一个**子命令调度器**——`bkp run …` 路由到 `cmd_run` 这种 git 风格 CLI 的内核

## 7.1 `bash -x`：让 shell 把每一步说出来

`set -x`（或在命令行 `bash -x script.sh`）让 bash **在执行每条命令前**先把它打印到 stderr：

```bash
$ bash -x <<'EOF'
greeting=hello
echo "$greeting world"
EOF
+ greeting=hello
+ echo 'hello world'
hello world
```

每行 trace 前缀默认是 `+ `（来自变量 `PS4`）。看到的：

- 变量已经**展开**（`$greeting` 变成 `hello`）
- 单引号里"展开后"的值——bash 替你呈现"shell 实际看到了什么"

90% 的"为什么我的脚本在那台机器上不动"，加 `bash -x` 五分钟搞定。

## 7.2 让 trace 自报家门：`PS4`

默认 `PS4='+ '` 太朴素——脚本一长就分不清这条 trace 是哪个文件、哪个函数、哪一行。bash 给我们留了几个延迟展开的变量：

| 变量             | 含义                                |
| ---------------- | ----------------------------------- |
| `BASH_SOURCE[0]` | 当前正在执行的源文件路径            |
| `LINENO`         | 当前正在执行的命令的行号            |
| `FUNCNAME[0]`    | 当前所在的函数名（顶层时未定义）    |
| `BASH_LINENO`    | 调用栈上每一帧的行号                |

把它们塞进 PS4：

```bash
PS4='+ [${BASH_SOURCE##*/}:${LINENO}:${FUNCNAME[0]:-main}] '
```

注意是**单引号**——延迟到每次 trace 时才展开，所以 `$LINENO` 是被 trace 那条命令的行号，而不是设置 PS4 那一行的行号。`${FUNCNAME[0]:-main}` 是个 idiom：`FUNCNAME[0]` 在顶层不存在（数组为空），用 `:-` 默认成 "main"，trace 里就不会出现空白。

```
+ [bkp:42:cmd_run] manifest_build "$src"
+ [bkp:43:cmd_run] (( count+=1 ))
+ [lib/log.sh:18:log_info] echo "[INFO] $1" >&2
```

**这条 PS4 已经够你打 95% 的 bash 仗了。**

### 局部开 / 关 trace

```bash
foo() {
    set -x
    do_suspicious
    set +x
}
```

只有 `do_suspicious` 一行被 trace。可惜 `set -x` 的作用域是"shell 设置位"，不是函数 local——子函数也会被 trace、上层调用方也仍然在 trace 状态。要彻底"区域化 trace"，把可疑代码塞进**子 shell** `(...)` 里 set -x，子 shell 一退出 trace 就消失。

## 7.3 `bkp` 的 `--debug` 开关

实践里你不会让用户每次都写 `bash -x bkp run`——而是**把 `bash -x` 暴露成 CLI 选项**：

```bash
bkp --debug run photos
```

主程序看到 `--debug` 就调 `enable_debug`，相当于把后续所有命令翻成"trace 模式"。这就是本章 `enable_debug` 干的事：

```bash
enable_debug() {
    PS4='+ [${BASH_SOURCE##*/}:${LINENO}:${FUNCNAME[0]:-main}] '
    export PS4
    set -x
}
```

`export` 是为了：如果 bkp 自己 fork 了子进程（譬如 ch6 的 `parallel_run` 起的 worker），它们继承 PS4，trace 风格统一。

这条命令"调用之后就不返回 trace-off 状态"——这是有意的：调试模式开了就开到底，整次 run 都看得见。如果你想做"只 trace 某段"，把那段包子 shell：`( set -x; risky_block )`。

## 7.4 长选项解析：手写 case 而非 getopts

bash 自带的 `getopts` 只懂**短选项** `-d -j 4`，**不懂**长选项 `--debug --jobs=4`。要长选项就得自己写。

下面是 `bkp` 的长选项解析骨架（本章 `parse_args` 的实现思路）：

```bash
parse_args() {
    local debug=0 jobs= keep=
    local -a excludes=() pos=()
    local end_of_opts=0
    local arg

    while (( $# > 0 )); do
        arg=$1; shift

        if (( end_of_opts )); then
            pos+=("$arg"); continue
        fi

        case $arg in
            --)            end_of_opts=1 ;;
            --debug)       debug=1 ;;
            --jobs=*)      jobs=${arg#--jobs=} ;;
            --jobs)        jobs=$1; shift ;;
            --exclude=*)   excludes+=("${arg#--exclude=}") ;;
            --exclude)     excludes+=("$1"); shift ;;
            --*)           echo "unknown option: $arg" >&2; return 2 ;;
            *)             pos+=("$arg") ;;
        esac
    done
    # ... 输出 key=value 行
}
```

要点：

1. **两种形式都要支持**：`--jobs=4` 和 `--jobs 4`。前者用 `--jobs=*` 模式 + `${arg#--jobs=}`；后者用 `--jobs)` 模式 + `shift`
2. **`--` 是终止标志**：UNIX 长期约定 `--` 之后所有 token 都是位置参数（即便长得像选项）。`bkp run -- --weird-filename`
3. **未知选项立刻报错** `--*) ...; return 2`，**不要**默默吞掉——用户拼错 `--depug` 你装作没看见，他要找半天
4. **位置参数保持顺序**：`pos` 是数组，按出现顺序 `+=`
5. **缺值检查**：`--jobs)` 之后立刻 `if (( $# == 0 )); then 报错; fi`，不要让后面的 `$1` 拿到一个不该拿的值

### 为什么不用 `getopt(1)` 命令？

GNU `getopt` 命令是支持长选项的，但：

- macOS 自带 BSD 版的 `getopt`，**不支持长选项**——你的脚本一带就只能跑 Linux
- 真要用就得 `getopt -o ... -l ... -- "$@"`，非常啰嗦
- 上面那段 case 才二十行，比配 getopt 还短

**所以本章选择手写。** 这也是 git、kubectl、docker 这种成熟 CLI 工具的真实做法。

### `getopts` 在哪里有用？

短选项的密集组合，比如 `ls -la` 等价于 `ls -l -a`。`bkp` 的长选项太多，没必要混。如果将来要加 `bkp -v` 一类的"短开关"，再用 `getopts` 不迟。

## 7.5 子命令调度：git 风格 CLI 的内核

`bkp run` / `bkp diff` / `bkp prune` 看起来是七八个命令，实现上是**一个**入口 + 子命令路由表：

```bash
dispatch() {
    if (( $# == 0 )); then
        echo "usage: bkp <command> [args...]" >&2
        return 2
    fi
    local cmd=$1; shift
    if ! declare -F "cmd_$cmd" > /dev/null; then
        echo "ERROR: unknown command: $cmd" >&2
        return 1
    fi
    "cmd_$cmd" "$@"
}
```

每个子命令实现成 `cmd_<name>` 函数：

```bash
cmd_run()   { ... }
cmd_diff()  { ... }
cmd_prune() { ... }

dispatch "$@"
```

加新子命令 = 加一个 `cmd_xxx` 函数。**不需要修改 dispatch**——这是**约定优于配置**的精髓：函数命名约定本身就是注册表。

`declare -F "cmd_$cmd"` 探测函数是否定义。`> /dev/null` 是把它的"找到了，名字是 …"打印吞掉，我们只关心退出码。

为什么 unknown 走 rc=1 而不是 rc=2？UNIX 习惯里 rc=2 偏指"用法错误"（比如完全没传命令），rc=1 是"试了但不行"。可以争论，但要**一致**——本章 `dispatch` 用 1 给 unknown 命令、2 给空命令；`parse_args` 用 2 给所有解析错误。

## 常见坑速查

!!! danger "新手常见坑"
    1. **PS4 写双引号** `PS4="+ [$LINENO]"` —— $LINENO 在赋值那一刻就求值了，trace 行号永远是同一个；用单引号
    2. **`set -x` 一开就忘了关** —— 主程序入口处的开关写好 `--debug` 才开，否则 trace 把用户淹了
    3. **`getopts` 拿不到长选项** —— 默认它不认 `--debug`，要么混合写、要么彻底放弃 getopts
    4. **`--jobs 4` 缺值时不检查 `$#`** —— 直接 `jobs=$1` 拿到的是下一个真位置参数（如 `photos`），数据被偷
    5. **`--` 之后还在解析选项** —— 没设 `end_of_opts` 标志位，`bkp run -- --weird` 里 `--weird` 被当成未知选项
    6. **dispatch 里写 `eval`** —— 用 `declare -F` 探测 + `"cmd_$cmd" "$@"` 直接调用就够了，eval 引入注入风险

---

## 实验：`bkp` 的 CLI 模块

```
exercises/07-debug-cli/starter/lib/
  cli.sh   # enable_debug / parse_args / dispatch
```

### 函数契约

| 函数                         | 干什么                                                     |
| ---------------------------- | ---------------------------------------------------------- |
| `enable_debug`               | 设置 `PS4='+ [${BASH_SOURCE##*/}:${LINENO}:${FUNCNAME[0]:-main}] '`、export、`set -x` |
| `parse_args <args>...`       | 解析 `--debug` / `--jobs=N` / `--keep=N` / `--exclude=PAT`（可重复） / `--`；输出固定格式键值行；遇错 stderr + rc=2 |
| `dispatch <cmd> <args>...`   | 调 `cmd_<name>` 函数；空 cmd → usage + rc=2；未注册 → rc=1 |

### 输出格式（parse_args）

```
DEBUG=0|1
JOBS=N           （仅当 --jobs 出现）
KEEP=N           （仅当 --keep 出现）
EXCLUDES=p1,p2   （仅当 --exclude 至少一次；逗号连接）
POS=arg1 arg2    （总是输出；可能为空）
```

例子：

```
$ parse_args run --jobs=2 --debug photos
DEBUG=1
JOBS=2
POS=run photos
```

### 硬性要求

1. `parse_args` 必须支持 `--key=val` **和** `--key val` 两种形式
2. `parse_args` 遇到 `--` 切换为"剩余 token 全是位置参数"
3. 未知 `--option` → stderr 输出包含 `unknown option`，rc=2
4. `--jobs` / `--keep` / `--exclude` 缺值 → stderr 输出包含 `requires a value`，rc=2
5. `dispatch` 探测函数请用 `declare -F`，**不要用 `eval`**
6. `enable_debug` 必须 `export PS4`，让子进程也继承 trace 风格

### 提示

- `${arg#--jobs=}` 砍前缀：`arg=--jobs=4` → `4`
- 数组逗号 join 的稳妥写法：在子 shell 里改 IFS

    ```bash
    joined=$(IFS=,; printf '%s' "${excludes[*]}")
    ```

    在主 shell 里 `local IFS=,` 之后直接 printf 也行，但**那个 IFS 会持续到函数末尾**——后面 `${pos[*]}` 也会用逗号 join，把 `POS=run photos` 变成 `POS=run,photos`。这是真坑，本课作者写 solution 时第一版就翻车
- 探测函数：`declare -F "cmd_$cmd" > /dev/null`，看 rc=0 表示存在
- 测试 trace 时把可疑代码包成子 shell `( enable_debug; cmd )`，子 shell 退出 trace 就关；并把 stderr 重定向到文件再 grep 验证

### 跑测试

```bash
cd exercises/07-debug-cli
$EDITOR starter/lib/cli.sh
make grade
```

### 评分项

14 个测试 / 21 分：

- `parse_args`：空 / 仅位置 / `--debug` / `--jobs=` 与 `--jobs ` / `--keep=` / `--exclude` 重复 / 子命令混选项 / `--` 终止 / 未知选项 / 缺值（11 个测试，16 分）
- `dispatch`：路由 + 透传 / 未知命令（2 个测试，3 分）
- `enable_debug`：trace 行带 PS4 标记（1 个测试，2 分）

---

## 健壮性渐进：本章引入 `bash -x` + `PS4`

| Ch  | 引入                          |
| --- | ----------------------------- |
| 1   | `set -e`                      |
| 2   | `set -u`                      |
| 3   | `nullglob`                    |
| 4   | `trap` + `local`              |
| 5   | `set -o pipefail`             |
| 6   | 并发原语下重新 exercise 前面五件套 |
| **7** | **`bash -x` + 自定义 `PS4`** ← 本章 |
| 8   | 幂等 + 集成测试                |

调试不是"出 bug 才用"——而是把 trace 工具内化成开发习惯。等到 ch8 做集成测试，前面所有章节的代码会被串起来跑，那时 `bkp --debug` 是 5 秒定位问题的关键。

---

## 延伸阅读

- `man bash`：**SHELL VARIABLES**（`PS4` / `BASH_SOURCE` / `FUNCNAME` 节）、**Shell Builtin Commands** 中的 `getopts`
- [BashFAQ #035](https://mywiki.wooledge.org/BashFAQ/035) —— 选项解析全景
- [Greg's Wiki: Debugging](https://mywiki.wooledge.org/BashGuide/Practices#Debugging)
- git/kubectl/docker 的源码也是好教材——它们的"子命令路由"几乎都是这个模式
