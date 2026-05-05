#!/usr/bin/env bash
# lib/log.sh — 分级日志。

: "${LOG_LEVEL_NUM:=1}"
: "${LOG_LEVEL:=info}"

log_set_level() {
    case ${1:-} in
        debug) LOG_LEVEL=debug; LOG_LEVEL_NUM=0 ;;
        info)  LOG_LEVEL=info;  LOG_LEVEL_NUM=1 ;;
        warn)  LOG_LEVEL=warn;  LOG_LEVEL_NUM=2 ;;
        error) LOG_LEVEL=error; LOG_LEVEL_NUM=3 ;;
        *)
            echo "log: unknown level '${1:-}', falling back to info" >&2
            LOG_LEVEL=info
            LOG_LEVEL_NUM=1
            return 1
            ;;
    esac
    return 0
}

_log_emit() {
    local label=$1 num=$2
    shift 2
    if (( num >= LOG_LEVEL_NUM )); then
        printf '[%s] %s\n' "$label" "$*" >&2
    fi
}

log_debug() { _log_emit DEBUG 0 "$@"; }
log_info()  { _log_emit INFO  1 "$@"; }
log_warn()  { _log_emit WARN  2 "$@"; }
log_error() { _log_emit ERROR 3 "$@"; }
