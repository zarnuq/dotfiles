#!/bin/sh
# EWW Dashboard launcher

EWW_DIR="$HOME/.config/eww"

# Detect which monitor to use (0 for laptop, 1 for desktop) and pick a scale.
# scale drives BOTH the CSS sizes (eww.scss via _scale.scss) and the window
# geometry (eww.yuck via the SCALE var). 1.0 = baseline (ultrawide, unchanged).
if wlr-randr | grep -q "DP-2"; then
    monitor="1"    # Desktop ultrawide (3440x1440)
    scale="1.0"
else
    monitor="0"    # Laptop (1920x1200) — shrink the dashboard to fit
    scale="0.85"   # <-- tune this: <1.0 smaller, >1.0 bigger
fi

DASH="eww --config $EWW_DIR/dash"

open_dash() {
    widgets="clock cpu net-graph tray weather notifications mpd outlook ports vpn"

    # CSS side: eww.scss does `@import "scale"` and multiplies px by $scale.
    printf '$scale: %s;\n' "$scale" > "$EWW_DIR/dash/_scale.scss"
    # Close first so `reload` doesn't try to re-render windows without their
    # `scale` arg, then reload to recompile the SCSS with the new $scale.
    $DASH close-all >/dev/null 2>&1 || true
    $DASH reload    >/dev/null 2>&1 || true

    # Geometry side: scale is a per-window arg (defwindow can't see globals).
    # Run them sequentially. The client process hands the instruction
    # to the daemon socket and exits immediately, leaving a clean process tree.
    for widget in $widgets; do
        $DASH open --screen "$monitor" --arg "scale=$scale" "$widget"
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
