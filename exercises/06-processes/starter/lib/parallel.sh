#!/usr/bin/env bash
#
# lib/parallel.sh — 受限并发的 job 运行器。
#
# bkp run --all --jobs=N 需要"同一时刻最多 N 个 job 在跑、有 job 跑完就立刻
# 替补下一个"。这就是经典的 worker pool。
#
# 契约（parallel_run <max_jobs>）：
#   - 从 stdin 一行一个读 job：`<name>\t<bash_command>`
#   - 同时最多 max_jobs 个在执行
#   - 每跑完一个，把 `<name>\t<rc>` 打到 stdout（**完成顺序**，不是输入顺序）
#   - 任意 job 失败 → return 1；全部 0 → return 0
#   - job 自身的 stdout/stderr 不捕获（直接出到 parallel_run 的 stdout/stderr）
#     —— 测试时建议在 job 命令里自己重定向到文件
#
# Note: 库不写 set -e/-u/-o pipefail；由 bkp 主程序入口启用。

# ---------------------------------------------------------------
# parallel_run <max_jobs>
#
# 工作循环：
#   1) 准备一个 tmpdir 存每个 job 的退出码（每个 job 一个文件）
#   2) "fill slots"：在并发上限内启动新 job，记录 pid → idx 映射
#   3) `wait -n -p donepid` 阻塞直到任意一个子进程退出，得到它的 pid
#   4) 读对应文件拿 rc，打印 `<name>\t<rc>`，pid 出表，回到 step 2
#   5) 全部 finished 之后清理 tmpdir
#
# 提示：
#   - 启动子任务的标准写法：
#         ( bash -c "${cmds[i]}"; echo $? > "$tmpdir/$i.rc" ) &
#         pid_to_idx[$!]=$i
#     用 ( ... ) 子 shell 是因为 `bash -c` 之后还要 echo $?
#     —— 这一对必须打包成"一个 wait 单位"
#   - `wait -n -p var` 是 bash 5.1+ 的语法，把"刚结束的那个子进程 pid"
#     写到 $var；非常方便
#   - rc=0 别 `(( rc != 0 )) && any_failed=1`，
#     因为 `(( 0 ))` 返回 1，set -e 会被触发；用 `if` 包起来
#   - 清理 tmpdir：`trap "rm -rf '$tmpdir'" RETURN` 或在末尾显式 `rm -rf`
# ---------------------------------------------------------------
parallel_run() {
    echo "lib/parallel.sh: parallel_run 未实现" >&2
    return 1
}
