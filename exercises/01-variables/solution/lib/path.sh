#!/usr/bin/env bash
# lib/path.sh — pure string-level path utilities for bkp.

path_expand_tilde() {
    local path=$1
    case $path in
        '~')   printf '%s\n' "$HOME" ;;
        '~/'*) printf '%s\n' "$HOME/${path#"~/"}" ;;
        *)     printf '%s\n' "$path" ;;
    esac
}

path_strip_trailing_slash() {
    local path=$1
    if [[ $path == "/" ]]; then
        printf '%s\n' "/"
        return
    fi
    while [[ $path == */ ]]; do
        path=${path%/}
    done
    printf '%s\n' "$path"
}

path_basename() {
    local path
    path=$(path_strip_trailing_slash "$1")
    printf '%s\n' "${path##*/}"
}

path_dirname() {
    local path d
    path=$(path_strip_trailing_slash "$1")
    case $path in
        */*)
            d=${path%/*}
            if [[ -z $d ]]; then
                printf '%s\n' "/"
            else
                printf '%s\n' "$d"
            fi
            ;;
        *)
            printf '%s\n' "."
            ;;
    esac
}

path_join() {
    local result=$1
    shift
    local part
    for part in "$@"; do
        result="${result%/}/${part#/}"
    done
    printf '%s\n' "$result"
}

derive_snapshot_name() {
    local ts=$1
    printf '%s\n' "${ts//:/-}"
}
