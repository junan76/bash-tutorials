#!/usr/bin/env bash
#
# lib/check.sh — preflight checks for bkp.
#
# 在 `bkp run` 真的开始拷文件之前，主程序会调用这些函数验证前置条件：源目录是
# 否能读、目标是否能写、是否已有任务在跑、配置项数值是否合法、任务名是否符合
# 命名规则……这些检查全部是"读一下、判断一下"，不会修改文件系统。
#
# 共同约定：
#   - 通过返回 0，**保持静默**
#   - 失败时往 stderr 打一行人话错误信息，return 非零
#   - **绝不主动 exit**——主程序自己决定怎么收拾
#
# Note: 库文件本身不写 `set -e` / `set -u`，这两个开关由 bkp 主程序入口启用，
# 否则会污染调用方环境。

# ---------------------------------------------------------------
# check_source_dir <path>
#
# 源目录必须满足：存在 && 是目录 && 当前进程可读。
#
# 通过示例：
#   mkdir /tmp/src && check_source_dir /tmp/src       # return 0, 静默
#
# 失败示例（任意一个不满足都失败）：
#   check_source_dir /no/such/path                    # 不存在
#   check_source_dir /etc/passwd                      # 不是目录
#
# 提示：用 -e、-d、-r 三个文件测试运算符依次判断；判断失败时 stderr 打错误。
# ---------------------------------------------------------------
check_source_dir() {
    echo "lib/check.sh: check_source_dir 未实现" >&2
    return 1
}

# ---------------------------------------------------------------
# check_target_writable <path>
#
# 目标目录必须满足：存在 && 是目录 && 当前进程可写。
# 与 check_source_dir 对称，只是把 -r 换成 -w。
#
# 注意：只检查目标本身，不递归向上找父目录。bkp 在调用这个函数前已经保证父目录
# 由 `bkp init` 创建过。
# ---------------------------------------------------------------
check_target_writable() {
    echo "lib/check.sh: check_target_writable 未实现" >&2
    return 1
}

# ---------------------------------------------------------------
# check_lock_free <lockfile>
#
# 检查"是否可以开始这个任务"。lock 文件里应当存的是上一次启动该任务的进程 PID。
#
# 判定规则（按顺序）：
#   1) lock 文件不存在 → 0（首次跑或上次正常结束）
#   2) lock 文件为空     → 0（视为残留, stale）
#   3) lock 内容不是合法十进制数字 → 1（malformed, 拒绝继续）
#   4) lock 内容是数字，但该 PID 已经不存在 → 0（stale lock，可以接管）
#   5) lock 内容是数字且该 PID 仍在运行 → 1（任务正在跑，不能并发）
#
# 提示：
#   - 用 `kill -0 <pid> 2>/dev/null` 探测进程是否存在（不真的发信号）
#   - 用 `pid=$(<"$lockfile")` 读文件内容（比 cat 快也少一个进程）
#   - 用 `[[ $pid =~ ^[0-9]+$ ]]` 判断是否纯数字
#
# 这一节的逻辑会在 ch4 被 lib/lock.sh 进一步包装（加 trap 自动清理）；
# 本章只负责"检查"。
# ---------------------------------------------------------------
check_lock_free() {
    echo "lib/check.sh: check_lock_free 未实现" >&2
    return 1
}

# ---------------------------------------------------------------
# check_positive_int <value> <field-name>
#
# 校验 <value> 是正整数（>= 1）。<field-name> 仅用于错误信息里指明出错字段。
#
#   check_positive_int 14 default_keep        # 0
#   check_positive_int 0  default_keep        # 1（0 不是正整数）
#   check_positive_int -3 default_keep        # 1
#   check_positive_int abc default_keep       # 1
#   check_positive_int '' default_keep        # 1（空字符串）
#
# 失败时 stderr 至少要包含 <field-name>，方便调用方定位。
#
# 提示：用 `[[ $value =~ ^[1-9][0-9]*$ ]]`——这个正则同时排除了空串、负号、小
# 数点、0 开头。
# ---------------------------------------------------------------
check_positive_int() {
    echo "lib/check.sh: check_positive_int 未实现" >&2
    return 1
}

# ---------------------------------------------------------------
# check_job_name <name>
#
# 任务名作为快照根目录的一级子目录名出现，所以要满足：
#   - 非空
#   - 长度 <= 64
#   - 只含 [a-zA-Z0-9_-]（**不允许斜线、点、空格**）
#   - 不能是保留字：`.`、`..`、`latest`
#     （`latest` 是 bkp 用来指向最新快照的软链接名）
#
# 通过：notes、photos-2025、my_backup
# 失败：(空)、..、latest、with space、a/b、.hidden
#
# 提示：长度用 `${#name}`；`case` 拦保留字最直白；正则用 `[[ =~ ]]` 完成字符集
# 检查。
# ---------------------------------------------------------------
check_job_name() {
    echo "lib/check.sh: check_job_name 未实现" >&2
    return 1
}
