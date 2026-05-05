#!/usr/bin/env bash
# lib/diff.sh — manifest 差异比较。

manifest_diff() {
    local old=$1 new=$2
    local -A old_h=() new_h=()
    local relpath size hash p

    while IFS=$'\t' read -r relpath size hash; do
        [[ -n $relpath ]] && old_h[$relpath]=$hash
    done < "$old"

    while IFS=$'\t' read -r relpath size hash; do
        [[ -n $relpath ]] && new_h[$relpath]=$hash
    done < "$new"

    {
        for p in "${!old_h[@]}"; do
            if [[ -z ${new_h[$p]+set} ]]; then
                printf -- '- %s\n' "$p"
            elif [[ ${old_h[$p]} != "${new_h[$p]}" ]]; then
                printf 'M %s\n' "$p"
            fi
        done
        for p in "${!new_h[@]}"; do
            [[ -z ${old_h[$p]+set} ]] && printf '+ %s\n' "$p"
        done
    } | sort -k2
}
