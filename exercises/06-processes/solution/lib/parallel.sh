#!/usr/bin/env bash
# lib/parallel.sh — 受限并发的 job 运行器。

parallel_run() {
    local max=$1
    local -a names=() cmds=()
    local name cmd
    while IFS=$'\t' read -r name cmd; do
        [[ -z $name ]] && continue
        names+=("$name")
        cmds+=("$cmd")
    done

    local n=${#names[@]}
    (( n == 0 )) && return 0

    local tmpdir
    tmpdir=$(mktemp -d)

    local started=0 finished=0
    local any_failed=0
    local -A pid_to_idx=()

    while (( finished < n )); do
        # Fill empty slots up to max
        while (( started < n && ${#pid_to_idx[@]} < max )); do
            local i=$started
            ( bash -c "${cmds[i]}"; echo $? > "$tmpdir/$i.rc" ) &
            pid_to_idx[$!]=$i
            started=$((started + 1))
        done

        local donepid=
        wait -n -p donepid 2>/dev/null
        if [[ -z $donepid ]]; then
            # Fallback if wait -n -p didn't set the pid (shouldn't happen on bash 5.1+)
            for pid in "${!pid_to_idx[@]}"; do
                if ! kill -0 "$pid" 2>/dev/null; then
                    donepid=$pid
                    break
                fi
            done
        fi

        local idx=${pid_to_idx[$donepid]}
        local rc
        rc=$(<"$tmpdir/$idx.rc")
        printf '%s\t%s\n' "${names[idx]}" "$rc"
        unset 'pid_to_idx[$donepid]'
        finished=$((finished + 1))
        if (( rc != 0 )); then
            any_failed=1
        fi
    done

    rm -rf "$tmpdir"
    return "$any_failed"
}
