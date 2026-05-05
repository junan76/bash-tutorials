#!/usr/bin/env bash
# lib/cli.sh — bkp 的 CLI 解析与调度。

# enable_debug
# 设置 PS4 让 trace 行带上 [文件:行:函数] 标记，然后开 set -x。
enable_debug() {
    PS4='+ [${BASH_SOURCE##*/}:${LINENO}:${FUNCNAME[0]:-main}] '
    export PS4
    set -x
}

# parse_args <args>...
# 输出键值行（顺序固定）：
#   DEBUG=0|1
#   JOBS=N        （只在 --jobs 出现时）
#   KEEP=N        （只在 --keep 出现时）
#   EXCLUDES=...  （只在 --exclude 出现至少一次时；逗号连接）
#   POS=...       （位置参数；总是输出，可能为空）
parse_args() {
    local debug=0 jobs= keep=
    local -a excludes=() pos=()
    local end_of_opts=0
    local arg

    while (( $# > 0 )); do
        arg=$1; shift

        if (( end_of_opts )); then
            pos+=("$arg")
            continue
        fi

        case $arg in
            --) end_of_opts=1 ;;
            --debug) debug=1 ;;
            --jobs=*) jobs=${arg#--jobs=} ;;
            --jobs)
                if (( $# == 0 )); then
                    echo "ERROR: --jobs requires a value" >&2
                    return 2
                fi
                jobs=$1; shift
                ;;
            --keep=*) keep=${arg#--keep=} ;;
            --keep)
                if (( $# == 0 )); then
                    echo "ERROR: --keep requires a value" >&2
                    return 2
                fi
                keep=$1; shift
                ;;
            --exclude=*) excludes+=("${arg#--exclude=}") ;;
            --exclude)
                if (( $# == 0 )); then
                    echo "ERROR: --exclude requires a value" >&2
                    return 2
                fi
                excludes+=("$1"); shift
                ;;
            --*)
                echo "ERROR: unknown option: $arg" >&2
                return 2
                ;;
            *)
                pos+=("$arg")
                ;;
        esac
    done

    printf 'DEBUG=%s\n' "$debug"
    [[ -n $jobs ]] && printf 'JOBS=%s\n' "$jobs"
    [[ -n $keep ]] && printf 'KEEP=%s\n' "$keep"
    if (( ${#excludes[@]} > 0 )); then
        local joined
        joined=$(IFS=,; printf '%s' "${excludes[*]}")
        printf 'EXCLUDES=%s\n' "$joined"
    fi
    printf 'POS=%s\n' "${pos[*]}"
}

# dispatch <cmd> [<args>...]
# 调 cmd_<name>。空命令 → usage + rc=2；未知命令 → 报错 + rc=1。
dispatch() {
    if (( $# == 0 )); then
        echo "usage: bkp <command> [args...]" >&2
        return 2
    fi
    local cmd=$1; shift
    if ! declare -F "cmd_$cmd" > /dev/null; then
        echo "ERROR: unknown command: $cmd" >&2
        return 1
    fi
    "cmd_$cmd" "$@"
}
