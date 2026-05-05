#!/usr/bin/env bash
# lib/lock.sh — 进程锁。
# 依赖：调用方需先 source lib/check.sh（提供 check_lock_free）。

lock_acquire() {
    local lockfile=$1
    if ! check_lock_free "$lockfile"; then
        return 1
    fi
    echo "$$" > "$lockfile"
    trap "lock_release '$lockfile'" EXIT
    return 0
}

lock_release() {
    local lockfile=$1
    rm -f "$lockfile"
    return 0
}
