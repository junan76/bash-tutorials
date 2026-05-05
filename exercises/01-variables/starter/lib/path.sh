#!/usr/bin/env bash
#
# lib/path.sh — pure string-level path utilities for bkp.
#
# All functions in this file MUST be:
#   - Pure: no filesystem access, no global state mutation
#   - Implemented using only bash parameter expansion
#     (no sed, awk, cut, basename, dirname, realpath)
#
# This file is `source`d by other modules of bkp; it only defines functions.
# 完整规约见 docs/capstone.md 的"模块分布"。
#
# Note: 库文件本身不写 `set -e`，否则会污染调用方的环境。`set -e` 由 `bkp`
# 主程序入口在 ch4 引入。

# ---------------------------------------------------------------
# path_expand_tilde <path>
#
# 把开头的 `~` 展开为 $HOME；其他形式原样返回。
#
#   path_expand_tilde "~/notes"     -> "$HOME/notes"
#   path_expand_tilde "~"           -> "$HOME"
#   path_expand_tilde "/abs/path"   -> "/abs/path"  (unchanged)
#   path_expand_tilde "rel/path"    -> "rel/path"   (unchanged)
#
# 注意：不支持 `~user` 形式（需要查 /etc/passwd），本练习只处理 `~` 和 `~/...`。
# ---------------------------------------------------------------
path_expand_tilde() {
    echo "lib/path.sh: path_expand_tilde 未实现" >&2
    return 1
}

# ---------------------------------------------------------------
# path_strip_trailing_slash <path>
#
# 去掉末尾所有 `/`，但保留单独的 `/`（根目录）。
#
#   path_strip_trailing_slash "/foo/"   -> "/foo"
#   path_strip_trailing_slash "/foo//"  -> "/foo"
#   path_strip_trailing_slash "/"       -> "/"
#   path_strip_trailing_slash "foo"     -> "foo"
# ---------------------------------------------------------------
path_strip_trailing_slash() {
    echo "lib/path.sh: path_strip_trailing_slash 未实现" >&2
    return 1
}

# ---------------------------------------------------------------
# path_basename <path>
#
# 返回路径的最后一个组成部分（类似 GNU `basename`）。先去掉尾部的 `/`。
#
#   path_basename "/a/b/c.txt"  -> "c.txt"
#   path_basename "/a/b/"       -> "b"
#   path_basename "single"      -> "single"
# ---------------------------------------------------------------
path_basename() {
    echo "lib/path.sh: path_basename 未实现" >&2
    return 1
}

# ---------------------------------------------------------------
# path_dirname <path>
#
# 返回路径的目录部分（类似 GNU `dirname`）。先去掉尾部的 `/`。
#
#   path_dirname "/a/b/c.txt"   -> "/a/b"
#   path_dirname "/a"           -> "/"
#   path_dirname "single"       -> "."
# ---------------------------------------------------------------
path_dirname() {
    echo "lib/path.sh: path_dirname 未实现" >&2
    return 1
}

# ---------------------------------------------------------------
# path_join <a> <b> [c...]
#
# 用单一的 `/` 拼接路径片段，去除中间多余的 `/`。
#
#   path_join "/a" "b" "c"      -> "/a/b/c"
#   path_join "/a/" "/b/" "/c"  -> "/a/b/c"
#   path_join "a" "b/"          -> "a/b/"   (尾部斜线保留)
# ---------------------------------------------------------------
path_join() {
    echo "lib/path.sh: path_join 未实现" >&2
    return 1
}

# ---------------------------------------------------------------
# derive_snapshot_name <iso_timestamp>
#
# 把一个 ISO-8601 风格的时间戳变成文件系统安全的快照目录名，主要是把 `:`
# 换成 `-`（macOS 原生 HFS+ 不允许 `:` 出现在文件名）。
#
#   derive_snapshot_name "2026-05-04T10:00:00"  -> "2026-05-04T10-00-00"
#   derive_snapshot_name "2026-05-04"           -> "2026-05-04"
# ---------------------------------------------------------------
derive_snapshot_name() {
    echo "lib/path.sh: derive_snapshot_name 未实现" >&2
    return 1
}
