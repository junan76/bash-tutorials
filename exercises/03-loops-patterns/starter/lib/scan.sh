#!/usr/bin/env bash
#
# lib/scan.sh — 遍历源目录，列出文件 / 一级条目。
#
# 这是 bkp manifest 生成（ch5）和拷贝阶段的输入：给一个源目录，告诉我都有哪些
# 文件需要处理。
#
# 共同约定：
#   - 输出路径都是**相对于 root**（不带 root 前缀，不带前导 `/`）
#   - 输出按字典序排序（用 `sort` 就好），方便 diff 与确定性测试
#   - 失败时 stderr 给提示并 return 非零；成功时静默
#
# 实现要求：
#   - 只能用 bash 内置（for 循环 + glob + shopt），**不要**调 `find`、`ls`
#   - 必须包含隐藏文件（dotfiles），bkp 用户备份的就是 `.config`、`.bashrc` 这类
#
# Note: 库文件本身不写 `set -e/-u`，由 bkp 主程序入口在 ch4 启用。

# ---------------------------------------------------------------
# scan_files <root>
#
# 递归列出 root 下**所有普通文件**（不含目录、不含符号链接）的相对路径。
#
# 示例：root = src，src 下有
#     src/a.txt
#     src/sub/b.txt
#     src/.hidden
#     src/sub/        （空目录会被忽略）
# 期望输出（字典序）：
#     .hidden
#     a.txt
#     sub/b.txt
#
# 提示：
#   - `shopt -s globstar nullglob dotglob` 是核心三件套
#       * globstar：让 `**` 递归匹配任意深度
#       * nullglob：没匹配时 glob 展开为空（默认会保留字面量 `**`）
#       * dotglob：让 glob 也匹配以 `.` 开头的文件
#   - 用子 shell `( ... )` 包住 shopt + 循环，避免污染调用方设置
#   - 用 `${f#"$root/"}` 砍掉前缀（注意把 root 末尾的 `/` 提前去掉）
#   - 最后管到 `sort` 拿到稳定顺序
# ---------------------------------------------------------------
scan_files() {
    echo "lib/scan.sh: scan_files 未实现" >&2
    return 1
}

# ---------------------------------------------------------------
# scan_top_entries <root>
#
# 列出 root **一级**下的所有条目（文件 + 目录都算），不递归。
#
# 示例：root = src，src 下有 file.txt 和 sub/
# 期望输出：
#     file.txt
#     sub
#
# 提示：
#   - 这是 nullglob 最值得讲的场景：空目录里 `for x in "$root"/*` 没有 nullglob
#     会让循环跑一次、`x` 是字面量 `"$root"/*`，下游全乱
#   - 同样要 dotglob 才能把隐藏条目带上
#   - 不需要 globstar（只列一级）
# ---------------------------------------------------------------
scan_top_entries() {
    echo "lib/scan.sh: scan_top_entries 未实现" >&2
    return 1
}
