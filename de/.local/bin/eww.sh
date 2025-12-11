#!/bin/sh

# Detect which monitor to use (0 for laptop, 1 for desktop)
if wlr-randr | grep -q "DP-2"; then
    monitor="1"  # Desktop monitor
else
    monitor="0"  # Laptop display
fi

if [ "$1" = "open" ]; then
    eww open --screen "$monitor" clock
    eww open --screen "$monitor" cpu
    eww open --screen "$monitor" tray
    eww open --screen "$monitor" ram
    eww open --screen "$monitor" disk
    eww open --screen "$monitor" network
    eww open --screen "$monitor" temps
    eww open --screen "$monitor" uptime
    eww open --screen "$monitor" weather
    eww open --screen "$monitor" notifications
    eww open --screen "$monitor" mpd
    eww open --screen "$monitor" updates
elif [ "$1" = "close" ]; then
    eww close-all
else
    echo "Usage: $0 {open|close}"
    exit 1
fi
