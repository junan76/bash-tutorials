#!/usr/bin/env bash
#
# lib/manifest.sh — sha256 清单生成与验证。
#
# bkp 的 manifest 是"哪个文件、多大、内容 sha256 是什么"的快照。后续
# `bkp diff` 用它做增量对比，`bkp verify` 用它检测 bit rot。
#
# 格式（与 docs/capstone.md 一致）：每行一条记录，三列以 **TAB** 分隔：
#     <相对路径>\t<字节数>\t<sha256-hex>
#
# 例：
#     notes/README.md	1024	c8d9e0f1...
#
# Note: 库本身不写 set -e/-u/-o pipefail；由 bkp 主程序入口启用。
#       但本章重点是 pipefail，函数内部对管道失败要稳得住。

# ---------------------------------------------------------------
# manifest_hash_file <path>
#
# 计算 <path> 的 sha256 并把 64 字符 hex 写到 stdout（带尾换行）。
#   - 文件不存在或不可读 → return 1，不写 stdout、不写 stderr
#   - 计算失败（罕见，比如 sha256sum 自身错） → return 1
#
# 提示：
#   - 守门：[[ -f $path && -r $path ]] || return 1
#   - 主体：sha256sum "$path" | cut -d' ' -f1
#     管道里 sha256sum 失败时，**默认情况下整个管道仍 return 0**——
#     因为 bash 取的是最后一个命令（cut）的退出码。这就是 pipefail
#     要解决的事。
#   - 在函数内"局部"启用 pipefail 的标准技巧：用子 shell 包住
#     ( set -o pipefail; sha256sum ... | cut ... )
#     子 shell 退出码就是管道的退出码，外层是否 pipefail 都不影响。
# ---------------------------------------------------------------
manifest_hash_file() {
    echo "lib/manifest.sh: manifest_hash_file 未实现" >&2
    return 1
}

# ---------------------------------------------------------------
# manifest_build <root>
#
# 从 stdin 读相对路径（一行一个，来自 ch3 的 scan_files），逐个：
#   1) 拼出绝对路径 root/relpath
#   2) 取文件大小（`stat -c %s`）和 sha256（manifest_hash_file）
#   3) 写一行 `<relpath>\t<size>\t<hash>` 到 stdout
#
# 顺序与 stdin 一致；空 stdin → 空 stdout + rc=0。
# 单个文件失败（hash 不出来）→ 写一条诊断到 stderr 后**继续**下一行，
# **不终止**整个 build。
#
# 提示：
#   - while IFS= read -r relpath; do ...; done   # 默认就读 stdin
#   - 用 `printf '%s\t%s\t%s\n'`，TAB 直接写在格式串里就行
# ---------------------------------------------------------------
manifest_build() {
    echo "lib/manifest.sh: manifest_build 未实现" >&2
    return 1
}

# ---------------------------------------------------------------
# manifest_verify <manifest_file> <root>
#
# 逐行解析 manifest，把 root 下对应文件的 sha256 重新算一遍：
#   - 完全一致 → 不输出
#   - 哈希不一致 → 把 `MISMATCH <relpath>` 打到 stdout
#   - 文件已不存在 → 把 `MISSING <relpath>` 打到 stdout
#
# 全部 OK return 0；任意问题 return 1。
#
# 提示：
#   - 行格式 `<relpath>\t<size>\t<hash>`，read 时用 IFS=$'\t'：
#       while IFS=$'\t' read -r relpath size expected; do ...; done < "$manifest"
#   - 用 bad=$((bad+1)) 计数；不要写 (( bad++ )) ——
#     在 set -e 下，(( bad++ )) 在 bad=0 时返回 1 会触发退出
#   - 最后 `(( bad == 0 ))` 作为函数最后一句，函数返回的就是它的退出码
# ---------------------------------------------------------------
manifest_verify() {
    echo "lib/manifest.sh: manifest_verify 未实现" >&2
    return 1
}
