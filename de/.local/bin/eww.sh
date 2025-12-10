#!/bin/sh

if [ "$1" = "open" ]; then
    eww open-many clock cpu tray ram disk network temps uptime weather notifications mpd updates
elif [ "$1" = "close" ]; then
    eww close-all
else
    echo "Usage: $0 {open|close}"
    exit 1
fi
