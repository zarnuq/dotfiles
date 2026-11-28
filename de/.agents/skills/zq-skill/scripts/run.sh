#!/bin/sh
# run.sh <fixture-dir> "<prompt>": one headless Claude session inside the fixture,
# stream-json saved to <fixture-dir>.jsonl. FLAGS=--safe-mode for the baseline.
# The run edits the fixture, so copy a fresh one per run.
set -e
dir=$(realpath "$1")
# a run that ignores the git rule must not reach a real repo, even with `git -C` or `cd ..`
export GIT_DIR=/nonexistent
cd "$dir" && claude -p $FLAGS --max-turns 40 --output-format stream-json --verbose "$2" \
    < /dev/null > "$dir.jsonl" 2> "$dir.err"
