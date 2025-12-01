#!/bin/bash
volume=$(pactl get-source-volume @DEFAULT_SOURCE@ | grep -o '[0-9]\+%' | head -1)
muted=$(pactl get-source-mute @DEFAULT_SOURCE@ | awk '{print $2}')

if [[ "$muted" == "yes" ]]; then
    echo "${volume:-N/A}"
else
    echo "^fg(f38ba8)${volume:-N/A}^fg()"
fi
