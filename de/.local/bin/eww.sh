#!/bin/sh
# EWW Dashboard launcher

EWW_DIR="$HOME/.config/eww"

# Detect which monitor to use (0 for laptop, 1 for desktop)
if wlr-randr | grep -q "DP-2"; then
    monitor="1"  # Desktop monitor
else
    monitor="0"  # Laptop display
fi

DASH="eww --config $EWW_DIR/dash"

open_dash() {
    widgets="clock cpu net-graph tray weather notifications mpd-volume outlook ports vpn"
    
    # Run them sequentially. The client process hands the instruction 
    # to the daemon socket and exits immediately, leaving a clean process tree.
    for widget in $widgets; do
        $DASH open --screen "$monitor" "$widget"
    done
}

case "$1" in
    open)
        open_dash
        ;;
    close)
        $DASH close-all
        ;;
    *)
        echo "Usage: $0 {open|close}"
        exit 1
        ;;
esac
