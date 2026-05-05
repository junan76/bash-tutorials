#!/usr/bin/env bash
# lib/scan.sh — 遍历源目录。

scan_files() {
    local root=${1%/}
    if [[ ! -d $root ]]; then
        echo "scan: not a directory: $root" >&2
        return 1
    fi
    (
        shopt -s globstar nullglob dotglob
        local f
        for f in "$root"/**/*; do
            if [[ -f $f && ! -L $f ]]; then
                printf '%s\n' "${f#"$root/"}"
            fi
        done
    ) | sort
}

scan_top_entries() {
    local root=${1%/}
    if [[ ! -d $root ]]; then
        echo "scan: not a directory: $root" >&2
        return 1
    fi
    (
        shopt -s nullglob dotglob
        local entry
        for entry in "$root"/*; do
            printf '%s\n' "${entry#"$root/"}"
        done
    ) | sort
}
