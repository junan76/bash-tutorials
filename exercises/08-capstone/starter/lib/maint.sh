#!/usr/bin/env bash
#
# lib/maint.sh — bkp 的快照维护操作：prune 与 restore。
#
# 这是 capstone 收尾章。两个函数都强调**幂等性**（idempotency）：
# 同一份输入跑两次 = 跑一次的最终状态。备份工具的核心信任来自这一条。
#
# 详细契约见 docs/chapters/08-capstone.md。

# ---------------------------------------------------------------
# prune_snapshots <snap_root> <keep>
#
# 在 <snap_root> 下查找所有 immediate 子目录（每个 = 一个时间戳快照），
# 按目录名字典序升序排列（时间戳 ISO 格式天然就是时间序），保留最新的
# <keep> 个，其余 rm -rf。
#
# 行为：
#   - <snap_root> 不存在 → "ERROR: snapshot dir not found: ..." 到 stderr，return 1
#   - <snap_root> 是空目录 → 什么都不做，return 0
#   - n <= keep → 什么都不做，return 0
#   - n > keep → 删 n - keep 个最老的，return 0
#
# 提示：
#   - 用 `for d in "$root"/*/; do [[ -d $d ]] || continue; ...; done`
#     —— `[[ -d $d ]]` 这一行同时承担 nullglob 不开启时"glob 没匹配"的兜底
#   - 排序：`printf '%s\n' "${arr[@]}" | LC_ALL=C sort` 然后用
#     `local IFS=$'\n'; arr=( $(...) )` 接回数组
#   - **幂等性自检**：跑两次 prune <root> <keep>，最终目录列表必须相同
# ---------------------------------------------------------------
prune_snapshots() {
    echo "lib/maint.sh: prune_snapshots 未实现" >&2
    return 1
}

# ---------------------------------------------------------------
# restore_snapshot <src_snapshot_dir> <dest_dir> [--force]
#
# 把 <src> 的内容拷贝进 <dest>。
#
# 行为：
#   - src 不存在 → "ERROR: source snapshot not found: ..." 到 stderr，return 1
#   - dest 不存在 → 创建并拷贝
#   - dest 存在且为空 → 直接拷贝
#   - dest 存在且非空且无 --force → "ERROR: dest not empty ..." 到 stderr，return 1
#   - dest 存在且非空且有 --force → 先 rm -rf dest，再 mkdir -p、cp -a
#
# 提示：
#   - 检查"非空"：`[[ -n "$(ls -A "$dest" 2>/dev/null)" ]]`
#     `ls -A` 列出除了 `.` `..` 之外的所有 entry；输出非空 = 目录非空
#   - 拷贝：`cp -a "$src"/. "$dest"/`，注意 `.` 让"内容"被拷贝而不是父目录
#     —— 不带 `.` 时 `cp -a /src /dest` 会变成 `/dest/src`
#   - **幂等性自检**：用 --force 跑两次，最终 dest 内容必须完全一致
# ---------------------------------------------------------------
restore_snapshot() {
    echo "lib/maint.sh: restore_snapshot 未实现" >&2
    return 1
}
