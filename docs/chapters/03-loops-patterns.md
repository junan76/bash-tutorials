# 第 3 章：循环、数组、模式匹配

> 对应实验：`exercises/03-loops-patterns/` —— 你将为 `bkp` 实现 `lib/scan.sh`（遍历源目录）和 `lib/filter.sh`（include/exclude 模式匹配）。
> 项目背景见 [Capstone：`bkp`](../capstone.md)。

## 学习目标

完成本章后，你应该能够：

- 写出 `for`/`while`/`until` 三种循环并知道何时该选哪一种
- 创建、追加、遍历、切片 bash 数组（包括关联数组的简介）
- 区分 glob、`globstar`、正则三套模式语法，写出正确的递归遍历
- 用 `shopt` 调出 `nullglob` / `dotglob` / `failglob`，把 glob 的"魔鬼细节"驯服
- 用 `case` 做模式分发，避免一长串 `elif`

## 3.1 循环：for / while / until

### `for ... in` —— 遍历"已知列表"

```bash
for f in *.txt; do
    echo "$f"
done

for i in 1 2 3 4 5; do echo "$i"; done

# C 风格（数学条件，少用一点）
for ((i=0; i<10; i++)); do echo "$i"; done

# 遍历数组（推荐写法）
for item in "${arr[@]}"; do echo "$item"; done
```

注意 `for f in *.txt`：右边是 **glob 展开后的多个词**，不是字符串列表。这就引出了 nullglob 那一组坑——见 3.4。

### `while` / `until` —— 条件循环

```bash
# 读文件每一行（最常见的 while 用法）
while IFS= read -r line; do
    process "$line"
done < input.txt

# until: while 的反向，直到条件为真才停
until [[ -e /tmp/ready ]]; do sleep 1; done
```

!!! tip "`while read` 的标准写法是 `IFS= read -r line`"
    - `IFS=` 防止 read 把行首尾的空白吃掉
    - `-r` 让反斜杠当字面量（不做转义解释）
    缺一个就会有奇葩 bug。这是 ShellCheck 反复唠叨的 SC2162。

## 3.2 数组

### 索引数组

```bash
# 创建
arr=(a b c d)
arr+=(e)               # 追加单个
arr+=(f g)             # 追加多个

# 访问
echo "${arr[0]}"       # 第一个元素
echo "${arr[-1]}"      # 最后一个
echo "${#arr[@]}"      # 长度

# 遍历——必须 "${arr[@]}" 加引号 + @
for x in "${arr[@]}"; do
    echo "$x"
done

# 切片
echo "${arr[@]:1:3}"   # 从索引 1 开始 3 个
```

!!! danger "`$arr` 不等于 `${arr[@]}`"
    `$arr` 等价于 `${arr[0]}`——只取第一个元素，新手最常踩。

!!! danger "`${arr[*]}` vs `${arr[@]}`"
    - 不加引号时两者一样
    - **加引号时**：`"${arr[*]}"` 把所有元素拼成一个字符串（用 IFS 分隔），`"${arr[@]}"` 保留每个元素是独立的词
    - 99% 的时候你想要 `"${arr[@]}"`

### 把字符串切成数组

```bash
path="src/.git/HEAD"
IFS=/ read -ra segments <<< "$path"
echo "${segments[0]}"  # src
echo "${segments[1]}"  # .git
echo "${segments[2]}"  # HEAD
```

`read -ra <name>` 把读到的内容按 IFS 分割成数组。`<<<` 是 here-string（把字符串当作 stdin）。本章的 `filter_path_excluded` 会用到。

### 关联数组（简介）

```bash
declare -A cfg
cfg[name]=alice
cfg[age]=30

for k in "${!cfg[@]}"; do      # 注意 ! 取的是 keys
    echo "$k=${cfg[$k]}"
done
```

bash 4.0+ 才有，不能在 macOS 自带的 `/bin/bash`（仍是 3.2）里用——所以 `bkp` 主线尽量不依赖关联数组。

## 3.3 glob、globstar 与正则——三套模式语法

bash 里"模式匹配"出现在不同上下文，**语法不一样**：

| 上下文                         | 模式语法                |
| ------------------------------ | ----------------------- |
| 文件名展开 `for f in *.txt`    | glob                    |
| `case $x in pattern) ...`      | glob                    |
| `[[ $x == pattern ]]`          | glob                    |
| `[[ $x =~ regex ]]`            | POSIX 扩展正则          |

**glob** 简表：

| 写法     | 含义                                       |
| -------- | ------------------------------------------ |
| `*`      | 任意字符（**不跨 `/`**）                   |
| `?`      | 任意单个字符                               |
| `[abc]`  | a、b、c 之一                               |
| `[!abc]` | 不是 a、b、c                               |
| `**`     | 跨 `/` 任意深度（**需要 `globstar`**）     |

```bash
echo *.txt              # 当前目录的 .txt 文件
echo src/**/*.c         # globstar：递归找所有 .c
shopt -s globstar
echo src/**/*.c         # 现在它真的是递归
```

!!! danger "case 里的模式不要加引号"
    ```bash
    case $name in
        "$pat")  ... ;;     # 这是字面量匹配（变量值会被当字符串）
        $pat)    ... ;;     # 这才是 glob 匹配
    esac
    ```
    只有当 `$pat` 包含 glob 元字符（`*`、`?`、`[`）时，去/留引号会让结果天差地别。

## 3.4 `shopt`：让 glob 守规矩

bash 默认的 glob 行为有几个反直觉的角落，`shopt` 可以一键修正：

| 选项           | 改了啥                                                   |
| -------------- | -------------------------------------------------------- |
| `nullglob`     | glob 没匹配时**展开为空**（默认是保留字面量 `*.tmp`）    |
| `dotglob`      | 让 `*` 也匹配 `.foo` 这种隐藏文件                        |
| `globstar`     | 让 `**` 真的递归                                         |
| `failglob`     | glob 没匹配时**报错退出**（更严格，不太常用）            |
| `nocaseglob`   | 大小写不敏感                                             |
| `extglob`      | 启用扩展 glob：`!(pat)`、`@(a|b)`、`+(...)` 等           |

```bash
# 激活后用一组安全的设置：
shopt -s nullglob globstar dotglob

for f in src/**/*; do            # 真正递归
    [[ -f $f ]] && process "$f"  # 跳过目录
done
```

### 别污染调用方——用子 shell 守住 shopt

`shopt` 改的是当前 shell 的设置。你写一个被 `source` 的库函数时，**不要直接** `shopt -s nullglob` 然后什么都不做——会污染调用者。

两种洁净方式：

```bash
# 方式 A：函数体放进子 shell
my_scan() (
    shopt -s nullglob globstar dotglob
    for f in "$1"/**/*; do
        [[ -f $f ]] && printf '%s\n' "$f"
    done
)

# 方式 B：保存 / 恢复
my_scan() {
    local saved
    saved=$(shopt -p nullglob globstar dotglob)
    shopt -s nullglob globstar dotglob
    ...
    eval "$saved"
}
```

A 更直白，本章实验推荐用 A。

## 3.5 `case`：模式分发的最佳形态

第 2 章已经预告过 `case`，这章给一个真实例子：

```bash
classify() {
    case $1 in
        *.tar.gz|*.tgz) echo "tar+gzip" ;;
        *.tar.bz2)      echo "tar+bzip2" ;;
        *.zip)          echo "zip" ;;
        .|..|latest)    echo "reserved" ;;
        [a-z]*)         echo "lowercase" ;;
        *)              echo "unknown" ;;
    esac
}
```

要点：

- 每分支以 `;;` 结束
- `|` 表示"或"
- 第一个匹配生效，不会贯穿
- 默认分支用 `*)`

`case` 在写命令分发器（ch7 的 `bkp` CLI）和 exclude 匹配（本章 `filter_match`）时是首选。

## 常见坑速查

!!! danger "新手常见坑"
    1. **`for f in *.tmp`** 没匹配时 `f` 是字面量 `*.tmp` —— `nullglob` 解决
    2. **`*` 不会匹配 dotfiles** —— `dotglob` 或显式 `.* *`
    3. **`**` 默认不递归** —— `globstar` 解决
    4. **`"${arr[*]}"` 与 `"${arr[@]}"`** 在加引号时含义不同
    5. **`while read` 没加 `IFS= -r`** 会吃空白和反斜杠
    6. **`case` 模式加引号** 会把 glob 退化成字面量

---

## 实验：`bkp` 的 scan 与 filter

`bkp run` 的核心动作是"把源目录里需要备份的文件挑出来"。这一步分两层：

1. **scan** —— 给我源目录下所有文件的完整列表
2. **filter** —— 哪些应该排除掉（比如 `.git`、`*.tmp`、`node_modules`）

本章实现两个独立的库：

```
exercises/03-loops-patterns/starter/lib/
  scan.sh       # scan_files / scan_top_entries
  filter.sh     # filter_match / filter_path_excluded
```

### `lib/scan.sh` 的两个函数

| 函数                | 干什么                                | 用到的工具                           |
| ------------------- | ------------------------------------- | ------------------------------------ |
| `scan_files`        | 递归列出所有普通文件的相对路径        | `globstar` + `nullglob` + `dotglob`  |
| `scan_top_entries`  | 只列一级条目                          | `nullglob` + `dotglob`               |

输出契约：相对于 root、不带前导 `/`、按字典序、每行一个。

### `lib/filter.sh` 的两个函数

| 函数                       | 干什么                                |
| -------------------------- | ------------------------------------- |
| `filter_match`             | 字符串 vs glob 列表，任一命中 → 0     |
| `filter_path_excluded`     | 路径整体或任意段命中任一 pattern → 0  |

### 硬性要求

1. **只能用 bash 内置 + `sort`**——不要 `find`、不要 `ls`
2. **`shopt` 改动用子 shell 包起来**，不污染调用方
3. 命中/通过返回 0；否则返回 1；保持静默

### 提示

- `scan_files` 实现核心：
  ```bash
  scan_files() (
      shopt -s globstar nullglob dotglob
      local f root=${1%/}
      for f in "$root"/**/*; do
          [[ -f $f && ! -L $f ]] && printf '%s\n' "${f#"$root/"}"
      done
  ) | sort
  ```
  注意函数体用的是 `()` 不是 `{}`——这就是子 shell。
- `filter_match` 用 `case $s in $pat) return 0 ;; esac`，记得 `$pat` 不要加引号
- `filter_path_excluded` 用 `IFS=/ read -ra segments <<< "$path"` 拆段，再双层循环
- 路径整体匹配也要做：`pattern="tmp/*/*"` 这种跨段模式只能整路径才能命中

### 跑测试

```bash
cd exercises/03-loops-patterns
$EDITOR starter/lib/scan.sh starter/lib/filter.sh
make grade
```

### 评分项

17 个测试覆盖每个函数的标准用法 + 关键边界，全部在 `tests/` 下。重点看：

- `scan_*` 的"空目录测试"——nullglob 没启用就过不了
- `scan_files` 的"含 dotfiles"——dotglob 没启用就漏掉 `.hidden`
- `scan_files` 的"深层嵌套"——globstar 没启用 `**` 退化成 `*`
- `filter_path_excluded` 同时检查"段匹配"和"整路径匹配"两个语义

---

## 健壮性渐进：本章引入 `nullglob`

继 ch1 的 `set -e`、ch2 的 `set -u` 之后，本章把 `nullglob` 加进 `bkp` 的健壮性套餐。

### 没有 `nullglob` 的世界很危险

```bash
#!/usr/bin/env bash
set -e

target_dir=$1

# 想：把 target_dir 下所有 .tmp 删了
for f in "$target_dir"/*.tmp; do
    rm "$f"
done
```

如果 `$target_dir` 下没有 `.tmp` 文件会怎样？bash 默认行为：循环跑一次、`$f` 是**字面量** `"$target_dir"/*.tmp`。然后 `rm "$target_dir"/*.tmp` 报 "No such file or directory"——这种情况下副作用还可控。

但换一个场景：

```bash
shopt -u nullglob   # 默认就这样
for f in /etc/foo/*.conf; do
    cp "$f" backup/
done
```

如果 `/etc/foo` 没匹配到任何 `.conf`，`cp` 会被调用一次、参数是字面量 `/etc/foo/*.conf` 和 `backup/`，结果是 `cp: '/etc/foo/*.conf': No such file or directory`——脚本默默打了个警告就过去了，备份步骤悄悄被跳过。

加上 `nullglob` 后，没匹配 → 循环跑零次，**正确反映了"没有要处理的文件"这个事实**。

### 在 `bkp` 里的位置

`lib/scan.sh` 用子 shell 局部启用 `nullglob`（库的策略，不污染调用方）。**主程序入口**则会作为常态启用：

```bash
# bkp 主程序（ch4 引入）
#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob
```

### 渐进路线提醒

- ch1：`set -e`
- ch2：`set -u`
- **ch3：`nullglob`** ← 本章
- ch4：`trap` + `local`
- ch5：`set -o pipefail`
- ch7：`shellcheck`
- ch8：幂等 + 集成测试

---

## 延伸阅读

- `man bash`：**Pattern Matching**、**Arrays**、**The Shopt Builtin**
- [BashGuide: Arrays](https://mywiki.wooledge.org/BashGuide/Arrays)
- [BashGuide: Pattern Matching](https://mywiki.wooledge.org/BashGuide/Patterns)
- [Bash Pitfalls](https://mywiki.wooledge.org/BashPitfalls) —— 重点 #1（`for f in $(ls)`）、#3（`for f in *.mp3`）
