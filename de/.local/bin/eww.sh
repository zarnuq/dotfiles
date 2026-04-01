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

DASH="eww --config $EWW_DIR/dash"

open_dash() {
    $DASH open --screen "$monitor" clock
    $DASH open --screen "$monitor" cpu
    $DASH open --screen "$monitor" tray
    $DASH open --screen "$monitor" network
    $DASH open --screen "$monitor" ipaddrs
    $DASH open --screen "$monitor" weather
    $DASH open --screen "$monitor" notifications
    $DASH open --screen "$monitor" mpd-volume
    $DASH open --screen "$monitor" updates
    $DASH open --screen "$monitor" fetch
    $DASH open --screen "$monitor" hwinfo
    $DASH open --screen "$monitor" outlook
    $DASH open --screen "$monitor" ports
    $DASH open --screen "$monitor" procs
    $DASH open --screen "$monitor" services
    $DASH open --screen "$monitor" notes
    $DASH open --screen "$monitor" vpn
}

case "$1" in
    open)
        open_dash
        ;;
    close)
        $DASH close-all
        ;;
    dash)
        open_dash
        ;;
    vpn)
        # Toggle VPN widget
        if $DASH active-windows | grep -q "vpn"; then
            $DASH close vpn
        else
            $DASH open --screen "$monitor" vpn
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
