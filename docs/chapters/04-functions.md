# 第 4 章：函数、作用域与库

> 对应实验：`exercises/04-functions/` —— 你将为 `bkp` 实现 `lib/log.sh`（分级日志）和 `lib/lock.sh`（基于 PID 文件的进程锁）。
> 项目背景见 [Capstone：`bkp`](../capstone.md)。

## 学习目标

完成本章后，你应该能够：

- 写出 bash 函数的标准形式，理解 `name() { ... }` 与 `name() ( ... )` 的区别
- 用 `local` 给函数变量加作用域，避免污染全局命名空间
- 理解 bash 函数"返回的是 exit code，不是值"，并掌握"通过 stdout 返出值"的惯用法
- 区分 `source` 和 `exec`／子 shell，知道库为什么必须 `source`
- 写一个把多文件库组织起来的 bash 项目，函数之间正确依赖
- 用 `trap` 注册退出钩子做清理（删临时文件、释放锁……）

## 4.1 定义函数：两种写法、一个差别

```bash
# 标准写法（{} 复合命令）
log_info() {
    printf '[INFO] %s\n' "$*" >&2
}

# 同一个 shell 进程里执行，能改全局变量、影响调用方的环境
greet() {
    name="alice"     # 这一行污染了全局！
    echo "hi, $name"
}
```

把 `{}` 换成 `()`：

```bash
# 子 shell 写法
scan_files() (
    shopt -s globstar nullglob
    for f in "$1"/**/*; do
        [[ -f $f ]] && printf '%s\n' "$f"
    done
)
```

差别只有一个、但很重要：

- `name() { ... }` —— 函数体在**当前 shell**执行，能修改全局
- `name() ( ... )` —— 函数体在**子 shell**执行，所有变量、`shopt`、`set` 改动都局限在内部，函数返回时自动还原

ch3 的 `scan.sh` 用 `()` 包裹，就是为了局部启用 `globstar`／`nullglob`／`dotglob` 而不污染调用方——**库写到外面要用的函数，建议默认用 `()`**。本章 `lib/log.sh`、`lib/lock.sh` 因为需要修改全局状态（`LOG_LEVEL_NUM`、`trap`），还是用 `{}`。

!!! tip "`function name() { ... }` 也能用，但不推荐"
    `function` 关键字是 bash 的扩展，POSIX shell 不认。坚持 `name() { ... }` 写法可移植性最好。

## 4.2 局部变量：`local` 的纪律

bash 默认所有变量都是全局的——这一点和绝大多数语言相反，是新手最容易踩的雷。

```bash
counter=0

bump() {
    counter=$((counter+1))   # 改的是全局
    local i=0                # 这一行的 i 是局部的
    for ((i=0; i<5; i++)); do : ; done
}

bump
echo "$counter"   # → 1
echo "$i"         # → （空，i 已经回收）
```

约定：

- **函数里凡是临时用的变量，都加 `local`**——参数 `local arg=$1`、循环变量 `local i`、状态 `local result`
- 显式想改全局的（如本章 `LOG_LEVEL_NUM`），不加 `local`，并在文件顶部用注释说明这是导出状态
- `local` 自己也是命令，调用失败会让函数继续——所以**不要把 `local` 和它要赋的命令替换写在一行**：

    ```bash
    local pid=$(cat lock)    # 危险：cat 失败也不会让 pid 赋值失败
    ```

    要分开：

    ```bash
    local pid
    pid=$(cat lock) || return 1
    ```

## 4.3 函数的"返回"：exit code 而不是值

bash 函数 `return` 的是一个 0–255 的整数，**语义和 `exit` 一模一样**——0 表示成功，非 0 表示失败：

```bash
is_dir() {
    [[ -d $1 ]]      # 这一行的 exit code 就是函数的 exit code
}

if is_dir /etc; then
    echo "yes"
fi
```

要返回**真正的"值"**（一个字符串、一个数字），bash 有两种惯用法：

```bash
# 1. 通过 stdout 返出 + 命令替换捕获
get_pid() {
    cat /var/run/foo.pid
}
pid=$(get_pid)

# 2. 通过引用参数（约定一个变量名）改写——nameref / "out param"
get_pid_into() {
    local -n out=$1
    out=$(cat /var/run/foo.pid)
}
get_pid_into result
echo "$result"
```

本章用第一种：`log_*` 把消息打到 stderr、`lock_acquire` 通过 `return 0/1` 表达成功失败。

!!! warning "不要把"消息"和"值"混着写到 stdout"
    日志、警告、进度条这类**给人看**的输出走 stderr；只有"业务值"才走 stdout。否则一旦调用方写 `pid=$(my_func)`，把日志也吃进去了。本章 `lib/log.sh` 强制 `>&2` 就是这个原因。

## 4.4 `source` vs 执行：库为什么必须 `source`

`bash foo.sh` 和 `./foo.sh`（前提是有 shebang 和执行权限）是**起一个新进程**跑脚本——里面定义的函数和变量随子进程一起消失。

```bash
$ cat lib.sh
greet() { echo "hi"; }

$ bash lib.sh
$ greet         # → command not found
```

要把库的函数装进**当前 shell**，必须用 `source`（或等价的 `.`）：

```bash
$ source lib.sh
$ greet         # → hi
```

所以本章实验里，所有测试都是这样开头的：

```bash
source "$EXERCISE_DIR/starter/lib/log.sh"
log_info "..."
```

`bkp` 主程序也类似——主程序顶部一组 `source` 把所有 `lib/*.sh` 装进来，之后才能调用 `lock_acquire`、`scan_files` 等。

## 4.5 多文件库的组合：依赖与"上游 source"

到 ch4 为止你已经写了四个库：

```
lib/path.sh    # ch1
lib/check.sh   # ch2
lib/scan.sh    # ch3
lib/filter.sh  # ch3
lib/log.sh     # ch4 ← 新
lib/lock.sh    # ch4 ← 新
```

`lib/lock.sh` 内部要调 `check_lock_free`——这个函数是 ch2 的 `lib/check.sh` 提供的。组合方式有两种：

```bash
# 方式 A：库自己 source 它的依赖
# lib/lock.sh
source "$(dirname "${BASH_SOURCE[0]}")/check.sh"
lock_acquire() { check_lock_free "$1" || return 1; ... }

# 方式 B：库假定调用方已经 source 好依赖
# lib/lock.sh
# 依赖：调用方需先 source lib/check.sh
lock_acquire() { check_lock_free "$1" || return 1; ... }
```

本课程统一用**方式 B**。理由：

- `bkp` 主程序在入口集中 source 所有库，依赖关系一处可见
- 不用处理"同一个库被 source 两次会不会有副作用"
- 容易做单元测试——测试自己控制 source 哪些库

代价：调用方有责任按正确顺序 source。这一点会在 `bkp` 主程序的 `source_libs` 函数里集中处理。

## 4.6 `trap`：让"无论怎么死"都能清理

很多资源（锁文件、临时目录、后台进程）在程序结束时**必须释放**。但程序结束的方式有很多：

- 正常 `exit 0`
- 出错 `exit 1`
- `set -e` 在某行触发的退出
- 用户按 Ctrl-C
- `kill` 信号

如果手动在每个出口写释放代码，必然漏。`trap` 的作用就是注册一个钩子，让 shell 在**任何**这些情况下都自动跑：

```bash
trap "rm -f /tmp/$$.tmp" EXIT
echo "..." > /tmp/$$.tmp
# ... 哪怕这里 exit 1, 哪怕被 Ctrl-C, /tmp/$$.tmp 都会被清理
```

常用信号：

| 信号    | 触发                                         |
| ------- | -------------------------------------------- |
| `EXIT`  | 任何方式的 shell 退出（推荐用这个，覆盖最广）|
| `INT`   | Ctrl-C                                       |
| `TERM`  | `kill <pid>` 默认信号                         |
| `ERR`   | 配合 `set -e`，命令失败时触发                 |

本章 `lock_acquire` 在拿到锁后注册 `trap "lock_release '$lockfile'" EXIT`，shell 不管以什么姿势退出，锁都会被释放。

!!! tip "trap body 的引号语义"
    ```bash
    trap "lock_release '$lockfile'" EXIT
    ```
    外层 `"..."` —— `$lockfile` **现在**展开（注册 trap 时锁定值）
    内层 `'...'` —— 让展开后的字面量在 trap 触发时原样传进 `lock_release`

    如果写成单引号 `'lock_release "$lockfile"'`，`$lockfile` 会推迟到 trap 触发时才展开——若那时变量已经被覆盖，删错文件。

## 常见坑速查

!!! danger "新手常见坑"
    1. **没加 `local`** —— 函数里 `i=0` 改的是全局
    2. **`local pid=$(...)`** —— `local` 吞掉子命令的 exit code
    3. **`return $string`** —— `return` 只接受 0–255 的整数
    4. **`./lib.sh` 加载库** —— 跑在子进程里，函数装不进当前 shell
    5. **trap 用单引号包整个 body** —— 变量推迟展开，可能删错东西
    6. **trap 写多次后一次覆盖前一次** —— 同一信号只能挂一个 handler

---

## 实验：`bkp` 的 log 与 lock

```
exercises/04-functions/starter/lib/
  log.sh    # log_set_level / log_debug / log_info / log_warn / log_error
  lock.sh   # lock_acquire / lock_release
```

### `lib/log.sh` 契约

| 函数                       | 干什么                                                 |
| -------------------------- | ------------------------------------------------------ |
| `log_set_level <level>`    | 设置全局等级（`debug`/`info`/`warn`/`error`），非法值回退到 `info` 并 return 1 |
| `log_debug <msg...>`       | 等级 0；当前等级允许时打到 stderr，否则静默             |
| `log_info <msg...>`        | 等级 1                                                 |
| `log_warn <msg...>`        | 等级 2                                                 |
| `log_error <msg...>`       | 等级 3                                                 |

输出格式严格为 `[LEVEL] msg\n`，**所有日志只能写 stderr**（stdout 留给业务输出）。

### `lib/lock.sh` 契约

| 函数                        | 干什么                                                |
| --------------------------- | ----------------------------------------------------- |
| `lock_acquire <lockfile>`   | 调用 `check_lock_free` 判断是否可拿；可，则把 `$$` 写入文件并注册 EXIT trap；不可，return 1 |
| `lock_release <lockfile>`   | 删掉锁文件；幂等（不存在也不报错）                     |

依赖：`lib/check.sh` 的 `check_lock_free`。**测试在 `source lock.sh` 之前先 source ch2 的 `solution/lib/check.sh`**——这正是稳定接口约定（A1）的第一次现场展示。

### 硬性要求

1. 抽公共逻辑：`log_debug/info/warn/error` 共享一个内部 `_log_emit`
2. 用 `local` 给函数内部变量加作用域
3. `lock_release` 必须幂等（`rm -f` 即可）
4. `trap` 的 body 用 `"lock_release '$lockfile'"` 这种"双引号包外、单引号包内"的写法

### 提示

- log_emit 的核心：

    ```bash
    _log_emit() {
        local label=$1 num=$2
        shift 2
        if (( num >= LOG_LEVEL_NUM )); then
            printf '[%s] %s\n' "$label" "$*" >&2
        fi
    }
    ```

- 默认等级用 `: "${LOG_LEVEL_NUM:=1}"` 在文件顶部初始化，避免重复 source 时覆盖调用方已经设过的值
- `lock_acquire` 三步：check → 写 PID → 注册 trap
- `lock_release` 一行：`rm -f "$1"`

### 跑测试

```bash
cd exercises/04-functions
$EDITOR starter/lib/log.sh starter/lib/lock.sh
make grade
```

### 评分项

13 个测试，21 分，全部在 `tests/` 下。重点：

- log 测试同时检查"该打的打了"和"该静默的没打"——后者用 `exec 2>&1` + 精确 `stdout:` 匹配，stub 的"未实现"提示一旦泄漏到 stderr 就立刻被发现
- `lock_acquire` 用"正例 + 反例"对照（活跃锁拒绝、空闲锁接受），杜绝桩函数 return 1 蒙混过关
- trap 测试在 `bash -c` 子 shell 里 acquire 锁、用 sentinel 文件验证"持锁期间锁文件确实存在"，再让子 shell 自然退出，验证 trap 是否真的清理了锁

---

## 稳定接口约定（首次出现）

ch4 是第一个**显式**依赖前几章成果的章节。约定：

> 每一章的 grader 用上游章节的**官方 `solution/`** 作为依赖，而不是学生自己的实现。

体现在测试 YAML 里：

```bash
source "$EXERCISE_DIR/../02-conditions/solution/lib/check.sh"
source "$EXERCISE_DIR/starter/lib/lock.sh"
```

为什么这样：

- ch1 还没做的同学也能直接做 ch4——不会被"上一章的 bug"卡住
- 所有人的 ch4 在同一基线上比较：评分项目就是 lock.sh 本身，不是它的依赖
- 想验证"我自己写的 ch1 + 我自己写的 ch4 能不能一起跑"？把你的 ch1 实现拷到 `exercises/01-variables/solution/` 即可——测试默认就是从 `solution/` 读

代价：每章 `solution/` 必须保证质量，否则下游章节会塌。这一点由课程作者通过"每章合并前 solution 必须 100% 通过本章测试"的纪律来保证。

---

## 健壮性渐进：本章引入 `trap` + `local`

继 ch1 的 `set -e`、ch2 的 `set -u`、ch3 的 `nullglob` 之后，本章把 `trap` 和 `local` 加进 `bkp` 的健壮性套餐。

`trap` 解决的是**"清理工作不能漏"**的问题——锁、临时目录、后台进程都属于这一类。`local` 解决的是**"函数不要污染调用方"**的问题——大型 bash 项目崩溃的常见原因之一就是某个函数里漏写 `local i`，把调用方的 `i` 改了。

### 渐进路线提醒

- ch1：`set -e`
- ch2：`set -u`
- ch3：`nullglob`
- **ch4：`trap` + `local`** ← 本章
- ch5：`set -o pipefail`
- ch7：`shellcheck`
- ch8：幂等 + 集成测试

---

## 延伸阅读

- `man bash`：**SHELL FUNCTIONS**、**SHELL VARIABLES**（搜 `local`）、**SIGNALS**（搜 `trap`）
- [BashGuide: Functions](https://mywiki.wooledge.org/BashGuide/Practices#Functions)
- [Greg's Wiki: Sourcing](https://mywiki.wooledge.org/BashFAQ/060)
- [Bash Pitfalls #50](https://mywiki.wooledge.org/BashPitfalls#pf50)（`local var=$(cmd)`）
