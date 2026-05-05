#!/usr/bin/env bash
#
# lib/lock.sh — 文件锁，防止同一任务并发跑两次。
#
# 锁的本质：一个文件，里面写当前持锁者的 PID。
#   - 想拿锁 → 先 check_lock_free（来自 ch2 的 lib/check.sh），通过则把自己的
#     PID 写进去
#   - 拿到锁后注册一个 EXIT trap，让 shell 不管怎么死都把锁文件删掉，避免
#     "崩了之后下次再也跑不了" 的尸锁
#
# 依赖：本模块假设 `check_lock_free` 已经被定义。**调用方负责先 source
# `lib/check.sh`**——这是库之间组合的标准做法。
#
# 限制（已知，本章不展开）：
#   - 只能 acquire 一个锁；后一次 lock_acquire 会覆盖前一个的 trap
#   - 锁文件路径里的单引号会破坏 trap 的引用结构（生产代码会用更稳的方式）
#
# Note: 库不写 set -e/-u。

# ---------------------------------------------------------------
# lock_acquire <lockfile>
#
# 1) 调用 check_lock_free "$lockfile"。失败则原样 return 1（错误信息已经被
#    check_lock_free 打到 stderr）
# 2) 把当前进程 PID 写入 lockfile（覆盖式）
# 3) 注册 `trap "lock_release '<lockfile>'" EXIT` —— shell 退出时自动清理
# 4) return 0
#
# 提示：
#   - 写 PID 用 `echo "$$" > "$lockfile"`
#   - trap body 用双引号字符串，里面把 lockfile 用单引号围住：
#       trap "lock_release '$lockfile'" EXIT
#     双引号让 $lockfile 被现在展开（捕获当时的值），单引号让展开后的字面量
#     在 trap 触发时被正确传给 lock_release
# ---------------------------------------------------------------
lock_acquire() {
    echo "lib/lock.sh: lock_acquire 未实现" >&2
    return 1
}

# ---------------------------------------------------------------
# lock_release <lockfile>
#
# 删除 lockfile。**幂等**：文件不存在也不报错、不返回非零。
#
# 提示：`rm -f` 天生幂等。一行解决。
# ---------------------------------------------------------------
lock_release() {
    echo "lib/lock.sh: lock_release 未实现" >&2
    return 1
}
