#!/usr/bin/env bash
# lib/filter.sh — exclude 模式匹配。

filter_match() {
    local s=$1
    shift
    local pat
    for pat in "$@"; do
        case $s in
            $pat) return 0 ;;
        esac
    done
    return 1
}

filter_path_excluded() {
    local path=$1
    shift
    local -a segments
    IFS=/ read -ra segments <<< "$path"
    local pattern segment
    for pattern in "$@"; do
        case $path in
            $pattern) return 0 ;;
        esac
        for segment in "${segments[@]}"; do
            case $segment in
                $pattern) return 0 ;;
            esac
        done
    done
    return 1
}
