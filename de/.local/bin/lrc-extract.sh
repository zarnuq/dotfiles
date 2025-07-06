#!/bin/bash

# Requires: ffprobe (from ffmpeg), metaflac
# Usage: ./fix_lrc_timing.sh "01 - Donda Chant.flac"

input="$1"

if [[ ! -f "$input" ]]; then
    echo "File not found: $input"
    exit 1
fi

# Get duration in seconds
duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input")
duration=$(printf "%.2f" "$duration")

# Extract lyrics
lyrics=$(metaflac --show-tag=UNSYNCEDLYRICS "$input" | sed 's/^UNSYNCEDLYRICS=//')
if [[ -z "$lyrics" ]]; then
    lyrics=$(metaflac --show-tag=LYRICS "$input" | sed 's/^LYRICS=//')
fi

if [[ -z "$lyrics" ]]; then
    echo "No lyrics found in metadata."
    exit 1
fi

# Decode newlines
lyrics=$(printf "%b" "$lyrics")

# Split lyrics into array
IFS=$'\n' read -d '' -r -a lines <<< "$lyrics"

# Count how many lines are missing timestamps
untimed_lines=()
for line in "${lines[@]}"; do
    if [[ ! "$line" =~ \[[0-9]{2}:[0-9]{2}(\.[0-9]{2})?\] ]]; then
        untimed_lines+=("$line")
    fi
done

untimed_count=${#untimed_lines[@]}
interval=$(echo "$duration / ($untimed_count + 1)" | bc -l)

outfile="${input%.*}.lrc"
> "$outfile"

untimed_index=1

for line in "${lines[@]}"; do
    if [[ "$line" =~ \[[0-9]{2}:[0-9]{2}(\.[0-9]{2})?\] ]]; then
        echo "$line" >> "$outfile"
    else
        ts=$(echo "$interval * $untimed_index" | bc -l)
        min=$(printf "%02d" $(echo "$ts / 60" | bc))
        sec=$(printf "%05.2f" $(echo "$ts % 60" | bc))
        echo "[$min:$sec] $line" >> "$outfile"
        ((untimed_index++))
    fi
done

echo "Final .lrc saved to: $outfile"

