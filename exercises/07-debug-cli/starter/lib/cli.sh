#!/usr/bin/env bash
#
# lib/cli.sh — bkp 的 CLI 解析与调度。
#
# 三个函数一起构成 `bkp` 主程序的入口层：
#   enable_debug    设置 PS4，开 set -x，让后续命令打 trace
#   parse_args      解析 --flag 与位置参数，输出可被主程序读取的键值行
#   dispatch        根据子命令名调度到 cmd_<name> 处理函数
#
# 详细契约见 docs/chapters/07-debug-cli.md，以及 docs/capstone.md 的命令集。

# ---------------------------------------------------------------
# enable_debug
#
# 把 PS4 设成
#     '+ [${BASH_SOURCE##*/}:${LINENO}:${FUNCNAME[0]:-main}] '
# 并 export，然后 set -x 开 trace。这之后每条命令在执行前都会被打到
# stderr，前缀是上面的 PS4——但请注意 PS4 是**单引号**字符串，里面的
# 变量是 bash 在每次展开时延迟求值的，所以 $LINENO 会是当前那条命令
# 的行号，而不是设置 PS4 那一行的行号。
# ---------------------------------------------------------------
enable_debug() {
    echo "lib/cli.sh: enable_debug 未实现" >&2
    return 1
}

# ---------------------------------------------------------------
# parse_args <args>...
#
# 支持的选项：
#   --debug                 → DEBUG=1
#   --jobs=N | --jobs N     → JOBS=N
#   --keep=N | --keep N     → KEEP=N
#   --exclude=PAT | --exclude PAT （可重复）→ EXCLUDES=p1,p2,...
#   --                      → 终止选项解析，之后所有 token 都进 POS
#   其他 --foo               → ERROR + return 2
#
# 不以 -- 开头的 token 进 POS（保持出现顺序）。
#
# 输出（顺序固定）：
#   DEBUG=0|1
#   JOBS=N         （仅当 --jobs 出现）
#   KEEP=N         （仅当 --keep 出现）
#   EXCLUDES=...   （仅当 --exclude 至少一次；逗号连接）
#   POS=...        （总是输出；可能为空）
#
# 错误情况：
#   未知 --opt          → "ERROR: unknown option: --opt" 到 stderr，return 2
#   --jobs / --keep / --exclude 缺值 → "ERROR: --xxx requires a value"，return 2
#
# 提示：
#   - 用 case 处理 --opt=val（用 *=* 模式 + ${arg#--opt=} 取值）
#   - 数组累加：excludes+=("$val")
#   - 用 `local IFS=,` + `${arr[*]}` 把数组用逗号 join
# ---------------------------------------------------------------
parse_args() {
    echo "lib/cli.sh: parse_args 未实现" >&2
    return 1
}

# ---------------------------------------------------------------
# dispatch <cmd> [<args>...]
#
# 根据 cmd 调用同名 `cmd_<cmd>` 函数（透传剩余参数）。
#   空 cmd          → usage 到 stderr，return 2
#   未注册 cmd_xxx  → "ERROR: unknown command: xxx" 到 stderr，return 1
#   找到            → "cmd_<cmd>" "$@"，return 它的退出码
#
# 提示：
#   - 用 `declare -F "cmd_$cmd"` 探测函数是否定义
#   - 调用时一定写 `"cmd_$cmd" "$@"`，把数组完整透传
# ---------------------------------------------------------------
dispatch() {
    echo "lib/cli.sh: dispatch 未实现" >&2
    return 1
}
