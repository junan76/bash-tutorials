# 第 2 章：条件、test、布尔逻辑

> 对应实验：`exercises/02-conditions/` —— 你将为 `bkp` 实现 preflight 检查模块 `lib/check.sh`。
> 项目背景见 [Capstone：`bkp`](../capstone.md)。

## 学习目标

完成本章后，你应该能够：

- 准确区分 `[ ]`、`[[ ]]`、`test` 三种条件命令的差别，并知道**默认就用 `[[ ]]`**
- 熟练使用文件测试运算符（`-d`、`-f`、`-r`、`-w`、`-e`、`-L`、`-s`）
- 区分字符串比较（`=`、`!=`、`=~`）与数值比较（`-eq`、`-lt`、`(( ))`）
- 用 `&&` / `||` 写出短路求值的链式条件，并避开经典坑（`A && B || C` 不等于三元）
- 解释 `set -u` 解决什么问题，以及为什么主程序加它而库不加

## 2.1 条件命令的三种写法

bash 里"判断真假"有三种写法。它们指向**不同的内置命令**，行为也有微妙差别：

| 写法              | 实质                          | 推荐？        |
| ----------------- | ----------------------------- | ------------- |
| `test EXPR`       | 调用 `test` 内建命令          | 几乎不用      |
| `[ EXPR ]`        | `test` 的同义词，要求闭合 `]` | 兼容 POSIX 时用 |
| `[[ EXPR ]]`      | bash 关键字（不是命令）       | **首选**      |

`[[ ]]` 是 bash 关键字而不是命令，这意味着它**不做 word splitting 也不做 glob 展开**——这就是为什么它更安全：

```bash
file="my doc.txt"

[ -f $file ]    # 错：被拆成 [ -f my doc.txt ]，参数变多语法错
[ -f "$file" ]  # 对，但必须记得加引号
[[ -f $file ]]  # 对，[[ ]] 内部不会拆词，加不加引号都安全
```

`[[ ]]` 还支持：

- 正则匹配 `=~`
- 模式匹配（左边是字符串，右边是 glob 模式）
- 短路逻辑符 `&&` `||`（在 `[ ]` 里得用 `-a` `-o`，且早就被弃用）

!!! tip "默认就用 `[[ ]]`"
    本课程里，除非你写的是必须 POSIX 兼容的 `/bin/sh` 脚本，否则一律用 `[[ ]]`。
    `bkp` 的 shebang 是 `#!/usr/bin/env bash`，所以放心用。

## 2.2 文件测试运算符

写 bkp 这种工具，文件测试运算符你会用到吐：

| 运算符  | 真当且仅当                                |
| ------- | ----------------------------------------- |
| `-e f`  | 路径存在（不区分文件/目录/链接）          |
| `-f f`  | 是普通文件                                |
| `-d f`  | 是目录                                    |
| `-L f`  | 是符号链接                                |
| `-r f`  | 当前进程可读                              |
| `-w f`  | 当前进程可写                              |
| `-x f`  | 当前进程可执行（目录则是可进入）          |
| `-s f`  | 存在且**非空**                            |
| `f1 -nt f2` | f1 比 f2 新（newer than）             |
| `f1 -ot f2` | f1 比 f2 旧                            |
| `f1 -ef f2` | 两个路径指向同一个 inode（硬链接同源） |

```bash
# bkp 检查源目录的典型写法
if [[ -d $src && -r $src ]]; then
    echo "source 没问题"
fi

# 锁文件存在并且非空
if [[ -s $lockfile ]]; then
    pid=$(<"$lockfile")
fi
```

!!! warning "`-e` 与 `-f` 的差别"
    `-f` 不接受目录、链接、设备文件——只认普通文件。所以 `[[ -f /etc ]]` 是假。
    很多脚本本想"判断存在"却写了 `-f`，结果排除了目录。**先想清楚是要"普通文件"还是"任何路径"**。

## 2.3 字符串与数值比较

字符串和数字在 bash 里是**两套运算符**：

```bash
# 字符串
[[ $a == "$b" ]]      # 相等（注意右边要加引号防 glob 解释）
[[ $a != "$b" ]]      # 不等
[[ -z $s ]]           # 空字符串
[[ -n $s ]]           # 非空字符串
[[ $s == abc* ]]      # glob 模式匹配
[[ $s =~ ^[0-9]+$ ]]  # 正则匹配

# 数值（test/[/[[ 都用这套）
[[ $n -eq 0 ]]
[[ $n -lt 100 ]]
[[ $n -ge 1 ]]
```

数值比较还有**算术上下文** `(( ))`，这是更顺手的写法：

```bash
(( n > 0 ))           # 数学语法，> 不是重定向
(( ${#name} <= 64 ))  # 字符串长度
(( a + b > 100 ))
```

!!! danger "字符串/数值运算符不能交叉用"
    ```bash
    [[ "10" -lt "9" ]]   # 数值比较：false（10 > 9）
    [[ "10" < "9" ]]     # 字符串比较：true（按字典序，"10" < "9"）
    ```
    用错了不会报错——只会**默默给出错误结果**。这是 bash 最隐蔽的坑之一。

## 2.4 布尔逻辑与短路求值

在条件命令**外面**用 `&&` `||` 串命令：

```bash
mkdir -p backups && cd backups       # 前一个成功才执行后一个
cd /tmp || exit 1                    # 前一个失败才执行后一个
```

这两个运算符是**短路求值**——前一个的结果决定第二个跑不跑。常见用法：

```bash
# 守卫式：检查通过就继续
[[ -d $src ]] || { echo "source 不存在" >&2; return 1; }

# 默认值兜底
[[ -n $LOG_LEVEL ]] || LOG_LEVEL=info
```

在条件命令**里面**也可以串：

```bash
[[ -d $src && -r $src ]]              # 都满足
[[ -f $f || -L $f ]]                  # 其中一个满足
```

!!! danger "经典坑：`A && B || C` 不是三元运算符"
    很多人以为 `cond && a || b` 等于"如果 cond 则 a 否则 b"。**不对**：
    ```bash
    [[ -f log ]] && echo "found" || echo "missing"
    # 看起来像三元，但如果 echo "found" 失败（罕见但有可能），就会跑 echo "missing"
    ```
    要表达三元逻辑，老老实实用 `if … then … else … fi`。

## 2.5 `case`：另一种"条件"

`case` 不只是 if/elif 链的语法糖——它针对**模式匹配**做了优化：

```bash
case $name in
    .|..|latest)  echo "保留字"; return 1 ;;
    [a-zA-Z]*)    echo "OK" ;;
    *)            echo "不合法"; return 1 ;;
esac
```

注意点：

- 每个分支以 `;;` 结尾
- 模式是 **glob**（不是正则）
- `|` 表示"或"
- 第一个匹配的分支被执行，不会贯穿（除非用 `;;&` / `;&`，本课程不教）

`case` 在写"枚举值校验""命令分发"时比 if/elif 链直观得多。ch7 写 `bkp` CLI dispatcher 的时候你会大量用到。

## 常见坑速查

!!! danger "新手 5 个坑"
    1. **忘加引号**：`[ -f $file ]` 在 `$file` 含空格时炸（用 `[[ ]]` 可以避免）
    2. **数值比较错用 `<`**：`[[ "10" < "9" ]]` 是字典序比较，结果反直觉
    3. **`-f` 当作 `-e` 用**：判断目录或链接时 `-f` 会假阴性
    4. **`A && B || C` 当三元**：B 失败时会执行 C，悄悄出 bug
    5. **未引用的右值 `=` 比较**：`[[ $s == *.txt ]]` 是 glob 匹配，`[[ $s == "*.txt" ]]` 是字面量匹配——两个意思

---

## 实验：`bkp` 的 preflight 检查 —— `lib/check.sh`

`bkp run` 真正动手拷文件之前，主程序会先做一轮"飞行前检查"：源目录能读吗？目标目录能写吗？是不是已经有同名任务在跑？配置文件里写的 `default_keep=14` 真是正整数吗？任务名是不是合法标识符？

这些检查全部是**只读 + 字符串比对**——不改文件系统、不发信号、不写日志。本章你写的 `lib/check.sh` 就是这一层。

### 你要实现的 5 个函数

打开 `exercises/02-conditions/starter/lib/check.sh`，每个 stub 上方的注释写清了输入、输出、判定规则。

| 函数                       | 干什么                              | 主要工具                        |
| -------------------------- | ----------------------------------- | ------------------------------- |
| `check_source_dir`         | 源必须存在、是目录、可读            | `[[ -e ]]`、`[[ -d ]]`、`[[ -r ]]` |
| `check_target_writable`    | 目标必须存在、是目录、可写          | `[[ -e ]]`、`[[ -d ]]`、`[[ -w ]]` |
| `check_lock_free`          | 锁不存在 / stale 视为通过；活着拒绝 | `[[ -e ]]`、`kill -0`、`=~` 数字  |
| `check_positive_int`       | 配置项是正整数                      | `=~ ^[1-9][0-9]*$`              |
| `check_job_name`           | 任务名长度合法 + 字符集合法 + 非保留字 | `${#name}`、`case`、`=~`        |

### 共同约定

1. **通过 → return 0，stdout 与 stderr 都保持静默**
2. **失败 → 一行人话错误打到 stderr，return 非零**
3. **绝不主动 `exit`**——主程序自己决定怎么收尾

### 提示

- 三种条件写法都能完成本章的判断，但**首选 `[[ ]]`**——不会被 word splitting 坑。
- `check_lock_free` 里读 PID 时用 `pid=$(<"$lockfile")`，不要 `pid=$(cat ...)`——少一个进程，且 `$( <file )` 是 bash 专属技巧，本身就是教学点。
- `kill -0 $pid 2>/dev/null` 探测进程存在（不发任何信号）：成功 = 进程活着；失败 = 不存在或没权限。
- `check_positive_int` 用 `^[1-9][0-9]*$` 一个正则就排除了空串、负数、0 开头、小数点四种情况。
- `check_job_name` 推荐先用 `case` 把 `.`/`..`/`latest` 三个保留字直接挡掉，再用正则过字符集——比纯正则可读得多。

### 跑测试

```bash
cd exercises/02-conditions
$EDITOR starter/lib/check.sh
make grade
```

### 评分项

16 个测试覆盖每个函数的标准用法和关键边界，全部在 `exercises/02-conditions/tests/` 下，**没有隐藏测试**。打开看一眼能帮你理解每条契约具体怎么验证——尤其 `check_lock_free` 那 4 个 case，把"什么算 stale、什么算占用"明明白白讲清楚。

---

## 健壮性渐进：本章引入 `set -u`

继 ch1 引入 `set -e` 之后，本章把"健壮性套餐"加到第二项：`set -u`（== `set -o nounset`）。

`set -u` 让脚本在**引用未定义变量时立即报错退出**：

```bash
#!/usr/bin/env bash
set -u

echo "${USER}"        # OK，已定义
echo "${TYPO}"        # 立即报错：unbound variable
```

为什么需要它？看这个真实事故的简化版：

```bash
# 没有 set -u 的世界
backup_root="$HOME/backups"
rm -rf "$BACKUP_ROOT/$1"     # 注意大小写错了！$BACKUP_ROOT 是空
                             # 实际执行：rm -rf /<arg>，把根目录干了
```

`set -u` 会在第二行就罢工：`BACKUP_ROOT: unbound variable`，根目录得救。

### `set -u` 与函数参数

`set -u` 有个边角案例：访问**位置参数**也要小心。

```bash
set -u
foo() { local x=$1; echo "$x"; }
foo                    # 报错：$1 unbound
```

bkp 的库函数因此会用 `${1:-}` 模式表达"如果没传就当空"：

```bash
foo() { local x=${1:-}; ... }
```

但本章我们**没有**让 `lib/check.sh` 写 `set -u`。原因和 ch1 不写 `set -e` 一样——库被 `source` 时会污染调用方环境。**`set -u` 在 `bkp` 主程序入口启用，库自身保持中立**。

!!! note "渐进路线提醒"
    - ch1：`set -e`（错误立即退出）
    - **ch2：`set -u`（未定义变量立即退出）** ← 本章
    - ch4：`trap`（清理与信号处理）
    - ch5：`set -o pipefail`（管道任意一段失败都退出）
    - ch7：shellcheck（静态检查）
    - ch8：幂等 + 集成测试

`set -e` + `set -u` + `set -o pipefail` 三连习惯上写成一行：`set -euo pipefail`。这是社区共识的"严谨脚本三件套"——你会在 ch5 学完管道后看到完整版。

---

## 延伸阅读

- `man bash` 中 **CONDITIONAL EXPRESSIONS** 一节
- [BashGuide: Tests and Conditionals](https://mywiki.wooledge.org/BashGuide/TestsAndConditionals)
- [BashFAQ #105 — `set -e`/`set -u` 的边角案例](https://mywiki.wooledge.org/BashFAQ/105)
- [Bash Pitfalls](https://mywiki.wooledge.org/BashPitfalls) —— 重点看 #11 / #14 / #46
