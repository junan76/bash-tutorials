# 第 1 章：变量、引用、参数展开

## 本章重点

- `$var` 与 `${var}` 的差别，以及什么时候必须加大括号
- 单引号 vs 双引号 vs 反引号
- 命令替换 `$(cmd)`
- 参数展开三件套：
  - `${var#prefix}` / `${var##prefix}` —— 去除前缀
  - `${var%suffix}` / `${var%%suffix}` —— 去除后缀
  - `${var/find/replace}` —— 字符串替换

## 练习：批量文件重命名工具

实现 `starter/rename.sh`，支持两种模式：

```
rename.sh strip-prefix <prefix> <directory>
rename.sh change-ext <old_ext> <new_ext> <directory>
```

### 例子

```bash
# 把 photos/ 下所有以 IMG_ 开头的文件去掉前缀
$ ls photos/
IMG_001.jpg IMG_002.jpg other.png
$ ./rename.sh strip-prefix IMG_ photos
$ ls photos/
001.jpg 002.jpg other.png

# 把 notes/ 下所有 .txt 文件改成 .md
$ ./rename.sh change-ext txt md notes
```

### 要求

1. 参数不对（缺失、模式不认识）时打印用法到 **stderr** 并以非零退出码退出。
2. 用参数展开来构造新文件名，**不要**用 `sed` / `awk` / `cut` 这些外部命令。
3. 模式不匹配的文件不要动（比如 `change-ext txt md` 不应改动 `.png` 文件）。

### 提示

- 数组遍历：`for f in "$dir"/*."$ext"; do ...`
- 当 glob 没匹配到任何文件时会原样保留模式串，处理一下：`[[ -e "$f" ]] || continue`
- `mv -- "$old" "$new"`，`--` 防止文件名以 `-` 开头时被当成选项

## 跑测试

```bash
make grade
```

## 评分项

测试都在 `tests/` 下，全部公开。看一眼能帮你理解每个要求具体被怎么验证。
