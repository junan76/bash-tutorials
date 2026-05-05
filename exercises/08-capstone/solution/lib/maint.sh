#!/usr/bin/env bash
# lib/maint.sh — bkp 的快照维护操作：prune 与 restore。

# prune_snapshots <snap_root> <keep>
# 列出 <snap_root> 下所有 immediate 子目录，按名字字典序排序（ISO timestamp =
# 时间序），保留最新的 <keep> 个，其余 rm -rf。
prune_snapshots() {
    local root=${1%/}
    local keep=$2

    if [[ ! -d $root ]]; then
        echo "ERROR: snapshot dir not found: $root" >&2
        return 1
    fi

    local -a snaps=()
    local d
    for d in "$root"/*/; do
        [[ -d $d ]] || continue
        snaps+=("${d%/}")
    done

    local n=${#snaps[@]}
    (( n == 0 )) && return 0

    local IFS=$'\n'
    snaps=( $(printf '%s\n' "${snaps[@]}" | LC_ALL=C sort) )
    unset IFS

    local to_delete=$(( n - keep ))
    (( to_delete <= 0 )) && return 0

    local i
    for (( i = 0; i < to_delete; i++ )); do
        rm -rf "${snaps[i]}"
    done
}

# restore_snapshot <src_snapshot_dir> <dest_dir> [--force]
# 把 <src> 的内容拷贝进 <dest>。
#   - src 不存在 → rc=1 + stderr
#   - dest 已存在且非空且无 --force → rc=1 + stderr
#   - --force 时先把 dest 清空再拷
#   - 拷贝用 cp -a，保留权限/时间/链接
restore_snapshot() {
    local src=$1
    local dest=$2
    local force=0
    [[ ${3:-} == --force ]] && force=1

    if [[ ! -d $src ]]; then
        echo "ERROR: source snapshot not found: $src" >&2
        return 1
    fi

    if [[ -e $dest && -n "$(ls -A "$dest" 2>/dev/null)" ]]; then
        if (( ! force )); then
            echo "ERROR: dest not empty (use --force to overwrite): $dest" >&2
            return 1
        fi
        rm -rf "$dest"
    fi

    mkdir -p "$dest"
    cp -a "$src"/. "$dest"/
}
