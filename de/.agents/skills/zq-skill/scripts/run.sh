#!/bin/sh
# run.sh <fixture-dir> "<prompt>": one headless Claude session inside the fixture,
# stream-json saved to <fixture-dir>.jsonl. FLAGS=--safe-mode for the baseline.
# The run edits the fixture, so copy a fresh one per run.
set -e
dir=$(realpath "$1")
cd "$dir" && claude -p $FLAGS --max-turns 40 --output-format stream-json --verbose "$2" \
    < /dev/null > "$dir.jsonl" 2> "$dir.err"
