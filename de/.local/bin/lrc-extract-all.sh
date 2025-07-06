#!/bin/bash

fix_script="/home/miles/.local/bin/lrc-extract.sh"

if [[ ! -x "$fix_script" ]]; then
    echo "Error: $fix_script not found or not executable."
    exit 1
fi

# Find all .flac files recursively and run fix_lrc_timing.sh on each
find . -type f -iname '*.flac' -print0 | while IFS= read -r -d '' flacfile; do
    echo "Processing: $flacfile"
    bash "$fix_script" "$flacfile"
done

