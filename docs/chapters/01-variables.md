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

<!-- TODO: 补充讲义。建议覆盖：
  - 赋值语法（注意 `=` 两边不能有空格）
  - 变量名规则、命名约定（环境变量大写、局部小写）
  - `unset` 与空字符串的区别
-->

!!! warning "最常见的坑：等号两边别加空格"
    `var = value` 会被解析为 "执行命令 `var`，参数是 `=` 和 `value`"，而不是赋值。

## 1.2 引用规则：单引号 / 双引号 / 反引号

<!-- TODO: 三种引用的求值规则对比表。 -->

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

<!-- TODO: $(cmd) 的常见用法、嵌套、与反引号的差异。 -->

```bash
files_count=$(ls | wc -l)
log_dir="/var/log/$(date +%Y-%m)"
```

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

<!-- TODO: 补充每条的使用场景与教学例子。 -->

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
