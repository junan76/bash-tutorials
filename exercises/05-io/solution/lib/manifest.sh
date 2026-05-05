#!/usr/bin/env bash
# lib/manifest.sh — sha256 清单。

manifest_hash_file() {
    local path=$1
    [[ -f $path && -r $path ]] || return 1
    # 用子 shell 局部启用 pipefail，让 sha256sum 的失败能传出来
    ( set -o pipefail; sha256sum "$path" | cut -d' ' -f1 )
}

manifest_build() {
    local root=${1%/}
    local relpath size hash
    while IFS= read -r relpath; do
        # 跳过空行
        [[ -z $relpath ]] && continue
        local fullpath=$root/$relpath
        if [[ ! -f $fullpath ]]; then
            echo "manifest_build: skipping $relpath (not a regular file)" >&2
            continue
        fi
        size=$(stat -c %s "$fullpath") || {
            echo "manifest_build: stat failed for $relpath" >&2
            continue
        }
        if hash=$(manifest_hash_file "$fullpath"); then
            printf '%s\t%s\t%s\n' "$relpath" "$size" "$hash"
        else
            echo "manifest_build: hash failed for $relpath" >&2
        fi
    done
    return 0
}

manifest_verify() {
    local manifest=$1
    local root=${2%/}
    local relpath size expected actual fullpath
    local bad=0
    while IFS=$'\t' read -r relpath size expected; do
        [[ -z $relpath ]] && continue
        fullpath=$root/$relpath
        if [[ ! -e $fullpath ]]; then
            printf 'MISSING %s\n' "$relpath"
            bad=$((bad + 1))
            continue
        fi
        if ! actual=$(manifest_hash_file "$fullpath"); then
            printf 'MISSING %s\n' "$relpath"
            bad=$((bad + 1))
            continue
        fi
        if [[ $expected != "$actual" ]]; then
            printf 'MISMATCH %s\n' "$relpath"
            bad=$((bad + 1))
        fi
    done < "$manifest"
    (( bad == 0 ))
}
