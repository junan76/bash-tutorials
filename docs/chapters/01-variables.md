# 第 1 章：变量、引用、参数展开

> 对应实验：`exercises/01-variables/` —— 你将为 `bkp` 实现路径工具库 `lib/path.sh`。
> 项目背景见 [Capstone：`bkp`](../capstone.md)。

## 学习目标

完成本章后，你应该能够：

- 解释 `$var` 与 `${var}` 的区别，并知道什么时候**必须**用大括号
- 准确区分单引号、双引号、反引号在求值时的行为
- 用参数展开（前/后缀剥离、字符串替换、默认值）替代 `sed` / `cut` 解决常见字符串处理任务
- 在脚本中正确加引号，避免 word splitting 与 glob 展开导致的隐藏 bug

## 1.1 变量与赋值

bash 里所有变量都是字符串——没有 int、bool、struct 这些类型，连"数字"都是字符串（只有进入 `(( ))` 算术上下文时才被临时当作数字）。这是 bash 最重要的初学认知。

```bash
name=alice         # 字符串赋值
count=42           # 也是字符串"42"，不是整数 42
empty=             # 空字符串（注意：变量"已设置"，值是空）
```

**赋值语法只有一条规则**：`=` 两边**不能有空格**。

```bash
var=value          # 对
var = value        # 错——bash 把它解析成"运行命令 var，参数是 = 和 value"
```

这个规则是 bash 跟所有现代语言不一样的地方，第一次写一定会踩。

### 变量名规则

- 只能是字母、数字、下划线
- 不能以数字开头
- **大小写敏感**：`$count` 和 `$Count` 是两个变量

### 命名约定（不是语法，是文化）

| 风格            | 用途                          | 例子                         |
| --------------- | ----------------------------- | ---------------------------- |
| `UPPER_SNAKE`   | 环境变量、导出的全局配置      | `PATH`、`HOME`、`BKP_CONFIG` |
| `lower_snake`   | 函数局部变量、脚本内部状态    | `src_dir`、`exit_code`       |
| `_leading`      | 私有/内部，不希望调用方使用   | `_log_emit`                  |

`bkp` 全程遵循这个约定——看到大写就知道是从环境读的、看到小写就知道是函数本地的。

### `unset` vs 空字符串

```bash
empty=             # 已设置，值是空串
unset notset       # 未设置

[[ -z $empty ]]    # 真——空串
[[ -z $notset ]]   # 真——未设置当作空串
```

大多数时候它们行为一样。但有一个关键差别：**`set -u` 下访问未设置变量会报错，访问空串变量不会**。所以下一章打开 `set -u` 之后，`${notset:-}` 这种"给未设置变量一个默认空值"的写法就成了 idiom。

!!! warning "最常见的坑：等号两边别加空格"
    `var = value` 会被解析为 "执行命令 `var`，参数是 `=` 和 `value`"，而不是赋值。

## 1.2 引用规则：单引号 / 双引号 / 反引号

bash 有三种引用风格，求值规则完全不同。这张表先放下来，下面的例子就都看得懂：

| 引用形式      | `$var` 替换 | `$(cmd)` 替换 | `\` 转义 | glob 展开 | word splitting |
| ------------- | :---------: | :-----------: | :------: | :-------: | :------------: |
| `'...'` 单引号 |   ✗         |     ✗         |   ✗      |   ✗       |       ✗        |
| `"..."` 双引号 |   ✓         |     ✓         |   ✓      |   ✗       |       ✗        |
| `` `...` `` 反引号 | ✓     | ✓（自身就是命令替换） | ✓ | ✗   |       ✗        |
| 无引号        |   ✓         |     ✓         |   ✓      |   ✓       |       ✓        |

**三条经验法则**：

1. **不变的字面量** → 单引号（最安全，告诉 bash 别动里面任何东西）
2. **要插值** → 双引号（保留字面量但允许 `$var` / `$(cmd)` / `\` 工作）
3. **想展开 glob 或拆词** → 不加引号（这是少数派情况，并且要明确知道自己在做什么）

```bash
path='/home/$USER/notes'    # $USER 不展开，path 字面量含 $USER
path="/home/$USER/notes"    # $USER 展开，path 是 /home/alice/notes
```

=== "双引号（保留字面量、做变量替换）"
    ```bash
    name="world"
    echo "Hello, $name!"   # Hello, world!
    ```

=== "单引号（完全字面量）"
    ```bash
    name="world"
    echo 'Hello, $name!'   # Hello, $name!
    ```

=== "反引号（命令替换，已过时）"
    ```bash
    today=`date +%F`       # 能用，但首选 $(...)
    ```

!!! danger "永远给变量加双引号"
    `"$var"` 而不是 `$var`。否则 `var="a b"` 在循环或参数传递里会被拆成两个词。

    ```bash
    file="my doc.txt"
    cat $file        # 错：相当于 cat my doc.txt
    cat "$file"      # 对
    ```

## 1.3 命令替换 `$(cmd)`

`$(cmd)` 把"运行 `cmd` 拿到的 stdout"嵌进当前位置——是 bash 里把命令输出当作值用的标准写法。

```bash
files_count=$(ls | wc -l)
log_dir="/var/log/$(date +%Y-%m)"
snap_name=$(date +%Y-%m-%dT%H:%M:%S)
```

### 与反引号 `` `cmd` `` 的差别

老脚本里你会看到 `` files_count=`ls | wc -l` ``——能用，但**首选 `$(...)`**，原因有两条：

1. **反引号无法干净嵌套**——嵌套时内层要写成 `` \`...\` ``，多层就成了反斜杠地狱。`$(...)` 直接套：

    ```bash
    today=$(date +%F -d "$(stat -c %y /etc/hostname | cut -d' ' -f1)")
    ```

2. **`$(...)` 视觉上跟 `${var}` 一致**——一眼能看出"这是要展开的东西"。

### 加引号的位置

```bash
files=$(ls)            # 对，$(...) 已经把整段 stdout 收进 $files
echo "$files"          # 对，引用展开时加引号防 word splitting
echo $files            # 错，多个文件名会被拆词，且 * 会被 glob

echo "Today: $(date)"  # 对，"$(...)" 在双引号里也安全
```

### 命令替换会**剥末尾换行**

```bash
echo "x
y
" > tmp.txt
content=$(cat tmp.txt)    # content 末尾的所有 \n 被剥掉
```

这是 feature 不是 bug——`$(date)` 你不希望末尾带换行。但如果你**需要**保留末尾换行（比如把文件原样塞进变量再写出来），用 `mapfile` 或在末尾加个 sentinel：`content=$(cat tmp.txt; printf x); content=${content%x}`。

## 1.4 参数展开三件套

参数展开是 bash 的"内建字符串处理库"——能用它解决的就别 fork `sed`/`awk`。

| 形式                    | 含义                       | 例子                                              |
| ----------------------- | -------------------------- | ------------------------------------------------- |
| `${var#pattern}`        | 从左侧剥离最短匹配前缀     | `f="IMG_001.jpg"; echo "${f#IMG_}"` → `001.jpg`  |
| `${var##pattern}`       | 从左侧剥离最长匹配前缀     | `p="/a/b/c.txt"; echo "${p##*/}"` → `c.txt`      |
| `${var%pattern}`        | 从右侧剥离最短匹配后缀     | `f="a.tar.gz"; echo "${f%.gz}"` → `a.tar`        |
| `${var%%pattern}`       | 从右侧剥离最长匹配后缀     | `f="a.tar.gz"; echo "${f%%.*}"` → `a`            |
| `${var/find/replace}`   | 替换第一个匹配             | `s="a-b-c"; echo "${s/-/_}"` → `a_b-c`           |
| `${var//find/replace}`  | 替换全部匹配               | `s="a-b-c"; echo "${s//-/_}"` → `a_b_c`          |
| `${var:-default}`       | 未设置或为空时用 default   | `echo "${EDITOR:-vi}"`                            |

每一条都对应一类**真实任务**——下面用 `bkp` 里会用到的场景把它们走一遍。

### 剥前缀：`${var#}` / `${var##}`

`#` 是从**左边**剥，单 `#` 最短匹配，双 `##` 最长匹配。

```bash
# 拿文件名（去掉路径）
fullpath=/home/alice/notes/2026-05-04.md
basename=${fullpath##*/}     # 2026-05-04.md  —— 最长前缀，砍到最后一个 /
toplevel=${fullpath#/*/}     # alice/notes/2026-05-04.md  —— 最短，砍到第二个 /

# 砍 ~ 前缀（path_expand_tilde 里要用）
input='~/notes'
rest=${input#"~/"}           # notes —— 注意 "~/" 加引号防 bash 自己 tilde 展开
```

### 剥后缀：`${var%}` / `${var%%}`

`%` 是从**右边**剥，规则同上。

```bash
# 拿目录（去掉文件名）
fullpath=/home/alice/notes/2026-05-04.md
dir=${fullpath%/*}           # /home/alice/notes —— 最短后缀，砍最后一个 /

# 拿扩展名前的部分
file=archive.tar.gz
stem_short=${file%.*}        # archive.tar  —— 砍最后一个 .
stem_long=${file%%.*}        # archive      —— 砍第一个 .

# 砍尾部斜线（path_strip_trailing_slash 里要用）
path=/home/alice/
clean=${path%/}              # /home/alice
```

### 字符串替换：`${var/}` / `${var//}`

单 `/` 替换第一个匹配，双 `//` 替换全部。

```bash
# bkp 把 ISO 时间戳里的 : 全部换成 -（文件名里 : 在 Windows/HFS+ 上不合法）
ts='2026-05-04T10:00:00'
safe=${ts//:/-}              # 2026-05-04T10-00-00

# 替换第一个
s='a-b-c'
echo "${s/-/_}"              # a_b-c
echo "${s//-/_}"             # a_b_c
```

### 默认值：`${var:-default}` 与朋友们

| 形式             | 含义                                  | 改 var 吗？ |
| ---------------- | ------------------------------------- | :---------: |
| `${var:-x}`      | 未设置或空 → 用 `x`，否则用 `var`      | ✗           |
| `${var:=x}`      | 未设置或空 → **赋值** `x` 并使用       | ✓           |
| `${var:+x}`      | 已设置且非空 → 用 `x`，否则空串        | ✗           |
| `${var:?msg}`    | 未设置或空 → 写 msg 到 stderr 并 exit  | ✗           |

```bash
# 给 EDITOR 一个回退值
exec "${EDITOR:-vi}" "$file"

# 强制要求传入参数
src=${1:?usage: bkp run <name>}

# 函数里 set -u 配合默认空值（ch2 会大量用）
process() {
    local debug=${DEBUG:-0}
    ...
}
```

`bkp` 全程会用 `${var:-}` 这一招——尤其是函数读 `$1 / $2 / $3` 时，可选位置参数永远写成 `${3:-}` 而不是裸 `$3`。

## 常见坑速查

!!! danger "新手常见 5 个坑"
    1. **`var = value`**：等号两边不能有空格
    2. **未引用的 `$x`**：在 `[ ]`、循环、命令参数里都可能炸
    3. **`for f in *.txt` 没匹配到**：`f` 会是字面量 `*.txt`。解决：`shopt -s nullglob` 或 `[[ -e "$f" ]] || continue`
    4. **大小写敏感**：`$Var` 和 `$var` 是两个变量
    5. **混用单双引号**：`'$var'` 不会展开

---

## 实验：`bkp` 的路径工具库 —— `lib/path.sh`

`bkp` 在很多地方需要处理路径——配置文件里写的 `~/notes` 要展开成绝对路径、生成快照目录名时要把时间戳里的 `:` 换成 `-`、扫描源目录前要去掉路径末尾的 `/`……这些都是**纯字符串处理**，不需要碰文件系统。

本章你写的 `lib/path.sh` 就是这一层工具，后续每章都会 `source` 它。

### 你要实现的 6 个函数

打开 `exercises/01-variables/starter/lib/path.sh`，里面是 6 个 stub 函数。每个函数的契约（输入、输出、边界）都在它正上方的注释里写得很清楚。

| 函数                         | 干什么                                | 主要用到的展开                           |
| ---------------------------- | ------------------------------------- | ---------------------------------------- |
| `path_expand_tilde`          | 把开头的 `~` 展开为 `$HOME`           | `${var#"~/"}`（**注意引号防 tilde 展开**）|
| `path_strip_trailing_slash`  | 去掉末尾 `/`，但保留单独的根 `/`      | `${var%/}` 循环                          |
| `path_basename`              | 取路径最后一段（类似 `basename`）     | `${var##*/}`                             |
| `path_dirname`               | 取目录部分（类似 `dirname`）          | `${var%/*}`                              |
| `path_join`                  | 用单一 `/` 拼接多段路径               | `${var%/}` 与 `${var#/}` 组合            |
| `derive_snapshot_name`       | 把 ISO 时间戳改成文件系统安全的名字   | `${var//find/replace}`                   |

### 硬性要求

1. **只用参数展开**——不要调用 `sed`、`awk`、`cut`、`basename`、`dirname`、`realpath` 等外部命令
2. **纯函数**——不读写文件系统、不修改全局变量
3. **结果用 `printf '%s\n'` 输出到 stdout**

### 提示

- `path_expand_tilde` 用 `case` 分情况，注意 `case` 的模式 `~` 要**单引号**括起来（写成 `'~'`），否则会被 bash 自己的 tilde 展开吃掉变成 `$HOME`
- `path_strip_trailing_slash` 注意 `/` 是特例（不能剥成空字符串）
- `path_basename` 可以先调 `path_strip_trailing_slash` 再 `${path##*/}`，这样 `/a/b/` 也能正确返回 `b`
- `path_dirname` 注意两个边界：`/foo` 的目录是 `/`、`foo` 的目录是 `.`
- `path_join` 用 `for part in "$@"; do ... done` 遍历，每段用 `${prev%/}/${next#/}` 拼

### 跑测试

```bash
cd exercises/01-variables
$EDITOR starter/lib/path.sh
make grade
```

### 评分项

12 个测试覆盖每个函数的标准用法和关键边界，全部在 `exercises/01-variables/tests/` 下，**没有隐藏测试**——规约即文档。打开看一眼能帮你理解每个函数的契约具体怎么验证。

---

## 健壮性渐进：本章引入 `set -e`

每章会**渐进式**地把"健壮性套餐"加进 `bkp`，到 ch8 收尾时变成完整的 `set -euo pipefail` + `trap` + shellcheck 流程。**本章只引入第一项**：`set -e`。

`set -e`（== `set -o errexit`）让脚本在**任何命令返回非零退出码时立即退出**。没有它，bash 默认是"踩着尸体往前走"——一个 `cp` 失败了，下一行 `rm` 照样跑，可能把事情搞得更糟。

```bash
#!/usr/bin/env bash
set -e

cp source dest          # 失败的话，下一行就不会执行
echo "copy succeeded"   # 只有 cp 成功才会到这里
```

!!! note "为什么 `lib/path.sh` 不写 `set -e`"
    库文件被 `source` 时，`set -e` 会污染调用方的环境。约定是**只在主程序入口加** `set -e`，库自己保持中立。`bkp` 的主程序在 ch4 引入这一行。

`set -e` 自己也有坑（管道里只看最后一个命令的退出码、子 shell 的特殊行为、命令在 `if`/`&&` 里时不触发），ch5 学完管道后我们会用 `set -o pipefail` 补这个洞。

---

## 延伸阅读

- `man bash` 中 **EXPANSION** 一节（最权威的参考）
- [BashGuide: Parameters](https://mywiki.wooledge.org/BashGuide/Parameters)
- [Bash Pitfalls](https://mywiki.wooledge.org/BashPitfalls) —— 真实项目里踩过的坑合集
