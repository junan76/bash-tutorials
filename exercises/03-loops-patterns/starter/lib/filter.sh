#!/usr/bin/env bash
#
# lib/filter.sh — 用 glob 模式判断路径是否被排除。
#
# bkp.conf 里用户写：
#     add_job notes --src=... --exclude=".git" --exclude="*.tmp"
#
# 在 ch5 manifest 阶段，bkp 会对 scan_files 列出的每个相对路径调用 filter，
# 决定要不要纳入备份。
#
# 共同约定：
#   - 模式是 **glob**（`*`, `?`, `[abc]`），不是正则
#   - 任一模式命中就算"排除"
#   - 通过 → return 0；不通过 → return 1；都保持静默
#
# Note: 库文件本身不写 `set -e/-u`。

# ---------------------------------------------------------------
# filter_match <string> <pattern>...
#
# 给定一个字符串和若干 glob 模式，**任意一个**完整匹配该字符串则 return 0；
# 否则 return 1。
#
#   filter_match "foo.tmp" "*.tmp"            -> 0
#   filter_match "build"   ".git" "build"     -> 0
#   filter_match "main.c"  "*.tmp" "*.log"    -> 1
#   filter_match "file7.bak" "file[0-9].bak"  -> 0
#
# 提示：用 `case` 做 glob 匹配比 `[[ ]]` 简洁——
#     case $s in
#         $pat) return 0 ;;
#     esac
# 注意 case 模式**不要**加引号（加了就变成字面量，glob 失效）。
# ---------------------------------------------------------------
filter_match() {
    echo "lib/filter.sh: filter_match 未实现" >&2
    return 1
}

# ---------------------------------------------------------------
# filter_path_excluded <path> <pattern>...
#
# 判断一个相对路径是否被任意 exclude 模式命中。两种方式都算命中：
#   1) 模式与**整路径**匹配     如 path="tmp/cache/x" pattern="tmp/*/*"
#   2) 模式与**任意一段**匹配   如 path="src/.git/HEAD" pattern=".git"
#                              或 path="logs/2026/run.log" pattern="*.log"
#
# 命中 → 0；都没命中 → 1。
#
#   filter_path_excluded "src/.git/HEAD" ".git"      -> 0
#   filter_path_excluded "logs/run.log" "*.log"      -> 0
#   filter_path_excluded "src/main.c" "*.tmp" ".git" -> 1
#
# 提示：
#   - 用 `IFS=/ read -ra segments <<< "$path"` 把路径切成数组
#   - 双层循环：外层遍历 patterns，内层遍历 segments
#   - 也别忘了对整路径再做一次匹配（命中 `tmp/*/*` 这种跨段模式）
# ---------------------------------------------------------------
filter_path_excluded() {
    echo "lib/filter.sh: filter_path_excluded 未实现" >&2
    return 1
}
