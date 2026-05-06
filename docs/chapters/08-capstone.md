# 第 8 章：综合 —— 健壮性收尾与集成

> 对应实验：`exercises/08-capstone/` —— 你将为 `bkp` 实现 `lib/maint.sh`，提供 `prune_snapshots`（清理老快照）和 `restore_snapshot`（恢复快照到指定路径）两个收尾操作；最后一个测试会把它们和前几章的模块串起来跑一次完整管线。
> 项目背景见 [Capstone：`bkp`](../capstone.md)。

## 学习目标

完成本章后，你应该能够：

- 解释**幂等性**（idempotency）对备份/运维工具为什么是核心信任
- 在 bash 里写出可被反复执行而结果不变的"破坏性"操作
- 用 `cp -a src/. dest/` 正确地拷贝**目录内容**而不是父目录
- 设计跨模块**集成测试**（拿前一章的 solution 当上游依赖）
- 用 `shellcheck` 给收尾代码做静态体检

## 8.1 幂等性：备份工具的命门

> *Idempotent: an operation that produces the same result whether applied once or many times.*

数学定义听起来抽象，但运维场景里它非常具体：

```bash
prune snapshots/ --keep 5    # 第一次运行，删 3 个，剩 5 个
prune snapshots/ --keep 5    # 第二次运行，剩多少？
```

正确答案：**还是 5 个**。如果第二次又删了 3 个、剩 2 个，那这个工具不能放进 cron——因为 cron 一定会跑很多次。

幂等性是 bash 备份/部署/迁移类脚本最常**漏掉**的一类正确性。它不是"功能 bug"，是"运维毒药"：

- 单测可能全过（每个 case 都只跑一次）
- 第一次手测看起来工作正常
- 上 cron 跑一周，数据被反复处理出诡异状态——这时候已经晚了

写 `prune_snapshots` 和 `restore_snapshot` 时，**心里默念两遍**：

> 同一份输入跑两次，最终状态必须等于跑一次的最终状态。

具体到本章两个函数：

| 操作 | 幂等含义 |
| --- | --- |
| `prune_snapshots root keep` | 跑两次：剩下的快照集合完全相同 |
| `restore_snapshot src dest --force` | 跑两次：dest 的内容树完全相同（同 sha256） |

第二条尤其值得停一下——`--force` 会先 `rm -rf dest` 再拷一遍。看起来"破坏性"，但**结果**是幂等的：dest 内容只取决于 src，不取决于 dest 之前长什么样。这是幂等性的另一面：**接受过程不幂等，但确保终态一致**。

## 8.2 `prune_snapshots`：按字典序保留最新 N 个

存储模型规约（详见 [Capstone 项目 → 存储模型](../capstone.md)）规定快照目录用 ISO-8601 时间戳命名：

```
~/backups/photos/snapshots/
  2026-03-01T10-00-00/
  2026-04-01T10-00-00/
  2026-05-01T10-00-00/
```

ISO-8601 的字段顺序（年-月-日-时-分-秒）让**字典序 = 时间序**——这是这门课里最划算的一次设计选择，意味着排序完全不需要解析时间：

```bash
printf '%s\n' "${snaps[@]}" | LC_ALL=C sort
```

`LC_ALL=C` 强制走字节序，避免本地化 locale 偷偷加规则。

### 不要靠 mtime 排

新手一个常见误区：用 `ls -t` 或读 `stat -c %Y` 拿 mtime 排序。这在生产环境会被反咬一口——任何 `touch`、`chmod`、`mv -T` 都可能让 mtime 不再代表"创建时间"。**目录名才是事实**，时间戳就是写死的标识符。

本章 test #7 就是检测这个：故意把"最老"那个目录 `touch` 一下让它的 mtime 变最新，看实现会不会被骗。靠字典序的实现完全无感。

### nullglob 的兜底

```bash
for d in "$root"/*/; do
    [[ -d $d ]] || continue
    snaps+=("${d%/}")
done
```

`*/` 是"只匹配目录"的 glob 写法。但如果 `$root` 是空目录、且 `nullglob` 没开，这个 glob 会**字面留下** `"$root"/*/`——`for` 就会跑一次 `d=$root/*/`。`[[ -d $d ]] || continue` 这一行**双保险**：

- nullglob 开了：根本进不来循环
- nullglob 没开：进了循环但 `[[ -d ]]` 把假货过滤掉

`bkp` 全局开了 `shopt -s nullglob`（ch3 引入），但写库函数时**别假设调用方都开了**——这条防御性写法是日常 idiom。

## 8.3 `restore_snapshot`：`cp -a src/. dest/` 的小学问

恢复快照看起来就是"拷贝目录"，但 bash 里"拷贝目录"是个雷区。

```bash
cp -a /backup/snap /home/alice/restored
```

如果 `/home/alice/restored` 已经存在，这条命令会变成 `/home/alice/restored/snap/...`——把整个 snap 目录套进 restored 里多一层。八成不是你想要的。

正确写法两条线：

**A. 拷贝内容到既有目录（本章用法）**

```bash
mkdir -p "$dest"
cp -a "$src"/. "$dest"/
```

`/.` 这个尾巴让 cp 拷的是 src 的"内容"——`.` 是 src 内部的"自己"，于是落到 dest 的就是平铺过去的子项，没有套层。

**B. 拷贝整个目录到不存在的父目录**

```bash
cp -a "$src" "$dest"
```

dest 必须不存在，cp 自己创建。但本章不走这条线，因为我们要支持 `--force` 先清空已存在的 dest。

`-a` 是 `-dR --preserve=all` 的简写：保留权限、时间戳、符号链接。备份还原必须用 `-a`，普通 `cp` 会丢权限位。

### 非空检测：`ls -A` 的 idiom

```bash
[[ -n "$(ls -A "$dest" 2>/dev/null)" ]]
```

- `ls -A` 列出 `.` 和 `..` 之外的所有 entry
- 包成命令替换；输出非空 = 目录里至少有一个东西
- `-n` 检测字符串非空
- `2>/dev/null` 吃掉 dest 不存在时的报错

不要写 `[[ -z $(ls "$dest") ]]`——`ls` 会把 `.` 和 `..` 列出来吗？看版本。`ls -A` 是稳的。

## 8.4 集成测试：跨章节对接

前面每章的练习都是隔离的——ch5 的 manifest 模块从来没和 ch3 的 scan 模块一起跑过。这章的 test #13 第一次把它们串起来：

```bash
source "$EXERCISE_DIR/../05-io/solution/lib/manifest.sh"
source "$EXERCISE_DIR/starter/lib/maint.sh"

# 1. 建 3 个快照，每个里都有 manifest.txt
# 2. prune 留 2 个最新
# 3. 对剩下的快照跑 manifest_verify，全部通过
# 4. restore 最新快照到 workdir，再用同一份 manifest 校验 workdir
```

这是 [stable-interface 约定](../capstone.md)落地的样子：本章测试用 ch5 的 **`solution/`** 而不是 student 自己的 ch5——保证 ch5 没做完不会 block ch8 的评分。

写集成测试的两条原则：

1. **拿真实模块拼**——而不是 mock 一个假 manifest_verify。集成测试的价值就在于"两个真东西放一起会不会出意外"
2. **整条管线只跑一次**，不要在测试里循环造数据。把"复杂场景"交给单测，集成测试关心"对接面"

## 8.5 `shellcheck`：bash 静态体检

bash 让你能跑起来很多其实是 bug 的代码：

- `[[ -n $var ]]` —— 变量没引号在某些情况会出问题，但 `[[ ]]` 容忍
- `local x=$(cmd)` —— `local` 把 `cmd` 的退出码吞掉，`set -e` 都救不了
- `for f in $(ls)` —— 文件名带空格直接拆字段

这些写法日常运行没事，到了边界条件就出血。`shellcheck` 是 bash 的 lint 工具，认得几百条这类反模式：

```bash
shellcheck exercises/08-capstone/solution/lib/maint.sh
```

把它接进 CI（或者你的编辑器插件）——比单测更早发现问题，0 成本。

> 本章评分**不强制** shellcheck 0 警告（因为 lint 是另一个维度），但建议写完拿它扫一遍。

---

## 实验：`bkp` 的 maint 模块

```
exercises/08-capstone/starter/lib/
  maint.sh   # prune_snapshots / restore_snapshot
```

### 函数契约

| 函数 | 行为 |
| --- | --- |
| `prune_snapshots <root> <keep>` | 留下 `<root>` 下字典序最大的 `<keep>` 个子目录，其余 `rm -rf`。空目录 / `keep>=n` 时 no-op；`<root>` 不存在 → stderr + rc=1 |
| `restore_snapshot <src> <dest> [--force]` | 把 `<src>` 内容平铺到 `<dest>`。dest 非空且无 `--force` → stderr + rc=1；有 `--force` → 先 rm 后拷；src 不存在 → stderr + rc=1 且不创建 dest |

### 硬性要求

1. `prune_snapshots` 必须**幂等**——同一对 `<root> <keep>` 跑两次结果相同
2. `prune_snapshots` 用**字典序**判定新旧，不准看 mtime / ctime
3. `prune_snapshots` 用 `[[ -d $d ]] || continue` 兜底 nullglob 未开的情况
4. `restore_snapshot` 用 `cp -a "$src"/. "$dest"/` 拷贝内容（`/.` 不能省）
5. `restore_snapshot` 在 src 不存在时**不能创建 dest**——错误退出前不能留下副作用
6. `--force` 路径上 `restore_snapshot` 必须**幂等**——连跑两次 dest 内容（含 sha256）一致

### 提示

- 排序后接回数组的 idiom：

    ```bash
    local IFS=$'\n'
    snaps=( $(printf '%s\n' "${snaps[@]}" | LC_ALL=C sort) )
    unset IFS
    ```

    用完立刻 `unset IFS`——和 ch7 的"local IFS=, 漏到下一行"是同一类陷阱。

- 非空目录检测：`[[ -n "$(ls -A "$dest" 2>/dev/null)" ]]`

- 可选位置参数 `--force` 的安全读法：`[[ ${3:-} == --force ]]`。`${3:-}` 给 `$3` 一个默认空串，避免 `set -u` 报 "unbound variable"

- **写完 prune 顺手做幂等自检**：

    ```bash
    prune_snapshots root 3 && a=$(ls root | sort)
    prune_snapshots root 3 && b=$(ls root | sort)
    [[ "$a" == "$b" ]] && echo idempotent || echo BUG
    ```

    test #4 就是这条自检的自动化版。

### 跑测试

```bash
cd exercises/08-capstone
$EDITOR starter/lib/maint.sh
make grade
```

### 评分项

13 个测试 / 21 分：

- `prune_snapshots`：基础 keep / keep>n / keep=0 / 幂等 / 空目录 / 缺失目录 / 字典序辨别（7 个测试，9 分）
- `restore_snapshot`：fresh dest / 拒绝非空 / `--force` 覆盖 / `--force` 幂等 / 缺失 src（5 个测试，9 分）
- 集成：把 ch5 的 `manifest_build`/`manifest_verify` 和本章的 `prune`/`restore` 串成一条管线（1 个测试，3 分）

---

## 健壮性渐进：本章收尾

| Ch  | 引入                          |
| --- | ----------------------------- |
| 1   | `set -e` + `#!/usr/bin/env bash` |
| 2   | `set -u`                      |
| 3   | `nullglob`                    |
| 4   | `trap` + `local`              |
| 5   | `set -o pipefail`             |
| 6   | 并发下重新 exercise 前面五件套 |
| 7   | `bash -x` + 自定义 `PS4`      |
| **8** | **幂等 + 集成测试 + shellcheck** ← 本章 |

到这里，"五件套 + nullglob + trap + 并发安全 + trace 工具 + 幂等 + 静态检查 + 集成测试" —— bash 工程化的全套基本功攒齐了。这套组合用在备份工具上是 demo，用在部署脚本、运维 cron、CI 钩子里是真本事。

---

## 课程结尾

恭喜——你把 `bkp` 写完了：

- ch1 `lib/path.sh`：路径展开与引用
- ch2 `lib/check.sh`：前置条件检查
- ch3 `lib/scan.sh` + `lib/filter.sh`：扫描与排除
- ch4 `lib/log.sh` + `lib/lock.sh`：日志与锁
- ch5 `lib/manifest.sh`：sha256 清单
- ch6 `bkp run --all` + `bkp diff`：并发与对比
- ch7 `lib/cli.sh`：CLI 调度与 `--debug`
- ch8 `lib/maint.sh`：prune 与 restore（**本章**）

把这些模块拼起来就是一份 600–900 行的本地增量备份工具。比"hello world 教程"显然厚一些，比"贡献 systemd"显然薄很多——刚好是 bash 适合的甜蜜点：把单机的、文件系统层面的、运维型的工作流写得稳、写得能复用。

接下来想往哪走，几条路：

- **接 cron**：写 systemd timer 或 cron entry 让 `bkp run --all` 每天跑
- **接通知**：在 `bkp run` 末尾发 desktop notification / 邮件
- **重写到 Python**：用同样的存储模型重写，对比两种语言在 IO/进程管理上的差异
- **看 [restic](https://restic.net/) 源码**：生产级备份工具的 Go 实现——快照、去重、加密、远程存储，比 `bkp` 多走十几步

---

## 延伸阅读

- [BashFAQ #112: Idempotency](https://mywiki.wooledge.org/BashFAQ/112)
- `man cp`：`-a` / `--archive` / `-T` 节
- [shellcheck.net](https://www.shellcheck.net/) —— 在浏览器里粘代码就能扫
- [rsnapshot](https://rsnapshot.org/) 与 [BackupPC](https://backuppc.github.io/backuppc/) —— 工业级硬链接快照工具，看它们的策略文件能学到很多
- Martin Fowler：[*Idempotent Receiver*](https://martinfowler.com/articles/patterns-of-distributed-systems/idempotent-receiver.html) —— 跳出 bash 看分布式系统里的幂等性
