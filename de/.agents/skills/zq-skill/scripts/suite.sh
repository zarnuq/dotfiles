#!/bin/sh
# suite.sh <new-dir>: build fresh fixtures from fixtures.py, run every scenario in
# two columns (6 at a time), then print check.py's table. Column flags: A (default
# none, i.e. zq) and B (default --safe-mode). A full run is 18 sessions, about $4.
set -e
export A="${A-}" B="${B---safe-mode}"
here=$(dirname "$(realpath "$0")")
out=$(realpath -m "$1")
[ -e "$out" ] && { echo "$out exists; pass a new dir" >&2; exit 1; }
python3 -I "$here/fixtures.py" "$out"
cut -f1 "$out/prompts.tsv" | sed 'p;s/$/-s/' | xargs -P 6 -I{} sh -c '
    n={}; p=$(awk -F"\t" -v n="${n%-s}" "\$1==n {print \$2}" "$1/prompts.tsv")
    case $n in *-s) export FLAGS="$B" ;; *) export FLAGS="$A" ;; esac
    "$2/run.sh" "$1/$n" "$p"' _ "$out" "$here"
python3 -I "$here/check.py" "$out"
