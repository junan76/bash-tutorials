#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat >&2 <<EOF
Usage: $(basename "$0") strip-prefix <prefix> <directory>
       $(basename "$0") change-ext <old_ext> <new_ext> <directory>
EOF
    exit 1
}

(( $# >= 1 )) || usage

mode="$1"
shift

case "$mode" in
    strip-prefix)
        (( $# == 2 )) || usage
        prefix="$1"
        dir="$2"
        for f in "$dir"/"$prefix"*; do
            [[ -e "$f" ]] || continue
            base="${f##*/}"
            new="${base#"$prefix"}"
            mv -- "$f" "$dir/$new"
        done
        ;;
    change-ext)
        (( $# == 3 )) || usage
        old="$1"
        new="$2"
        dir="$3"
        for f in "$dir"/*."$old"; do
            [[ -e "$f" ]] || continue
            mv -- "$f" "${f%."$old"}.$new"
        done
        ;;
    *)
        usage
        ;;
esac
