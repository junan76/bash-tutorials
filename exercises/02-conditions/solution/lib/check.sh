#!/usr/bin/env bash
# lib/check.sh — preflight checks for bkp.

check_source_dir() {
    local path=$1
    if [[ ! -e $path ]]; then
        echo "check: source 不存在: $path" >&2
        return 1
    fi
    if [[ ! -d $path ]]; then
        echo "check: source 不是目录: $path" >&2
        return 1
    fi
    if [[ ! -r $path ]]; then
        echo "check: source 不可读: $path" >&2
        return 1
    fi
    return 0
}

check_target_writable() {
    local path=$1
    if [[ ! -e $path ]]; then
        echo "check: target 不存在: $path" >&2
        return 1
    fi
    if [[ ! -d $path ]]; then
        echo "check: target 不是目录: $path" >&2
        return 1
    fi
    if [[ ! -w $path ]]; then
        echo "check: target 不可写: $path" >&2
        return 1
    fi
    return 0
}

check_lock_free() {
    local lockfile=$1
    if [[ ! -e $lockfile ]]; then
        return 0
    fi
    local pid
    pid=$(<"$lockfile")
    if [[ -z $pid ]]; then
        return 0
    fi
    if [[ ! $pid =~ ^[0-9]+$ ]]; then
        echo "check: 锁文件内容不是合法 PID: $lockfile" >&2
        return 1
    fi
    if kill -0 "$pid" 2>/dev/null; then
        echo "check: 任务正在运行 (pid=$pid, lock=$lockfile)" >&2
        return 1
    fi
    return 0
}

check_positive_int() {
    local value=$1 field=$2
    if [[ ! $value =~ ^[1-9][0-9]*$ ]]; then
        echo "check: $field 必须是正整数, 实际为: '$value'" >&2
        return 1
    fi
    return 0
}

check_job_name() {
    local name=$1
    if [[ -z $name ]]; then
        echo "check: 任务名不能为空" >&2
        return 1
    fi
    if (( ${#name} > 64 )); then
        echo "check: 任务名超过 64 字符: $name" >&2
        return 1
    fi
    case $name in
        .|..|latest)
            echo "check: 任务名是保留字: $name" >&2
            return 1
            ;;
    esac
    if [[ ! $name =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "check: 任务名只能包含 [a-zA-Z0-9_-]: $name" >&2
        return 1
    fi
    return 0
}
