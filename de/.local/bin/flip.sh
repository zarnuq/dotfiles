#!/bin/sh

# Get list of sinks, excluding Easy Effects sink by exact name
sinks="$(pactl list short sinks | awk '$2 != "easyeffects_sink" {print $2}')"

# Convert to list using set
set -- $sinks

# Store the sinks as positional parameters ($1, $2, ...)
sink_list="$@"

# Get current default sink
default=$(pactl info | grep "Default Sink" | awk '{print $3}')

# Find index of current sink
index=0
for sink in "$@"; do
    if [ "$sink" = "$default" ]; then
        break
    fi
    index=$((index + 1))
done

# Compute next index (loop to 0 if at end)
count=$#
next_index=$(( (index + 1) % count ))

# Get sink at next_index
i=0
for sink in "$@"; do
    if [ "$i" -eq "$next_index" ]; then
        next_sink="$sink"
        break
    fi
    i=$((i + 1))
done

# Set the next sink as default
pactl set-default-sink "$next_sink"

echo "Switched to: $next_sink"

