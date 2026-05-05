#!/usr/bin/env bash
#
# lib/diff.sh — manifest 差异比较。
#
# 给两份 manifest（ch5 的格式：`<path>\t<size>\t<sha256>`），输出三类变更：
#     + <path>     新出现
#     - <path>     被删
#     M <path>     路径不变、内容变了（hash 不一致）
#
# 输出按路径字典序排序，rc 始终为 0（"差异本身不是错误"）。
#
# 进程替换在本章的真实落点：bkp diff 实际从快照目录现场 build manifest，
# 而不是固定文件，所以会写成
#     diff <(manifest_build_from_snapshot a) <(manifest_build_from_snapshot b)
# manifest_diff 这一层只关心两份现成 manifest 的对比；进程替换的连接交给
# 调用方处理。

# ---------------------------------------------------------------
# manifest_diff <old_manifest> <new_manifest>
#
# 把两份 manifest 各自加载到关联数组（path → hash），再各取并集做比较：
#   - path 只在 old → 输出 `- path`
#   - path 只在 new → 输出 `+ path`
#   - 两边都有但 hash 不同 → 输出 `M path`
#   - 两边都有且 hash 相同 → 不输出
#
# 输出按 path 字典序排序。rc=0 始终。
#
# 提示：
#   - 关联数组：declare -A old_h new_h
#   - 读 manifest（TAB 分隔三列）：
#       while IFS=$'\t' read -r relpath size hash; do
#           [[ -n $relpath ]] && old_h[$relpath]=$hash
#       done < "$old"
#   - 检查 key 是否存在用 `[[ -n ${arr[$k]+set} ]]`（注意 `+set` 这个老把戏）
#   - 排序：把所有输出收集后 `| sort -k2`
# ---------------------------------------------------------------
manifest_diff() {
    echo "lib/diff.sh: manifest_diff 未实现" >&2
    return 1
}
