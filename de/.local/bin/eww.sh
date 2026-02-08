#!/bin/sh
# EWW Dashboard launcher
# Uses separate config directories for dash and vpn widgets

EWW_DIR="$HOME/.config/eww"

# Detect which monitor to use (0 for laptop, 1 for desktop)
if wlr-randr | grep -q "DP-2"; then
    monitor="1"  # Desktop monitor
else
    monitor="0"  # Laptop display
fi

open_dash() {
    eww --config "$EWW_DIR/dash" open --screen "$monitor" clock
    eww --config "$EWW_DIR/dash" open --screen "$monitor" volume
    eww --config "$EWW_DIR/dash" open --screen "$monitor" cpu
    eww --config "$EWW_DIR/dash" open --screen "$monitor" tray
    eww --config "$EWW_DIR/dash" open --screen "$monitor" ram
    eww --config "$EWW_DIR/dash" open --screen "$monitor" disk
    eww --config "$EWW_DIR/dash" open --screen "$monitor" network
    eww --config "$EWW_DIR/dash" open --screen "$monitor" temps
    eww --config "$EWW_DIR/dash" open --screen "$monitor" weather
    eww --config "$EWW_DIR/dash" open --screen "$monitor" notifications
    eww --config "$EWW_DIR/dash" open --screen "$monitor" mpd
    eww --config "$EWW_DIR/dash" open --screen "$monitor" updates
    eww --config "$EWW_DIR/dash" open --screen "$monitor" fetch
    eww --config "$EWW_DIR/dash" open --screen "$monitor" hwinfo
    eww --config "$EWW_DIR/dash" open --screen "$monitor" outlook
    eww --config "$EWW_DIR/dash" open --screen "$monitor" ports
    eww --config "$EWW_DIR/dash" open --screen "$monitor" procs
    eww --config "$EWW_DIR/dash" open --screen "$monitor" services
    eww --config "$EWW_DIR/dash" open --screen "$monitor" notes
}

open_vpn() {
    eww --config "$EWW_DIR/vpn" open --screen "$monitor" vpn
}

close_dash() {
    eww --config "$EWW_DIR/dash" close-all
}

close_vpn() {
    eww --config "$EWW_DIR/vpn" close-all
}

case "$1" in
    open)
        open_dash
        open_vpn
        ;;
    close)
        close_dash
        close_vpn
        ;;
    dash)
        open_dash
        ;;
    vpn)
        # Toggle VPN widget
        if eww --config "$EWW_DIR/vpn" active-windows | grep -q "vpn"; then
            close_vpn
        else
            open_vpn
        fi
        ;;
    *)
        echo "Usage: $0 {open|close|dash|vpn}"
        echo ""
        echo "  open  - Open all widgets (dashboard + vpn)"
        echo "  close - Close all widgets"
        echo "  dash  - Open only dashboard widgets"
        echo "  vpn   - Toggle VPN widget"
        exit 1
        ;;
esac
