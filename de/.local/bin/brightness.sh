#!/bin/sh
# Software brightness for ALL outputs (laptop panel + the 3 externals) via
# wl-gammarelay-rs. Dims the gamma curve per output — works on DP/HDMI monitors
# that have no /sys/class/backlight (brightnessctl/light can't touch those).
#
# Uses the D-Bus *session* bus that dwl already provides (dbus-run-session) — no
# system bus, no root, no i2c. Void has no busctl, so we use gdbus.
#
#   brightness.sh up | down     step by $STEP percent
#   brightness.sh set <0-100>   absolute percent (the eww slider calls this)
#   brightness.sh get           print current percent (for the eww poll)
#
# Per-monitor instead of all: change OBJ to /outputs/DP_2 (connector with - → _).

SVC="rs.wl-gammarelay"
IFACE="rs.wl.gammarelay"
OBJ="/"          # / = every output at once
STEP=5           # percent per key press
FLOOR=10         # never let the screen go fully black

prop_get() {
  gdbus call --session --dest "$SVC" --object-path "$OBJ" \
    --method org.freedesktop.DBus.Properties.Get "$IFACE" Brightness 2>/dev/null \
    | grep -oE '[0-9]+\.?[0-9]*' | head -n1
}

prop_set() {   # $1 = double 0.00..1.00
  gdbus call --session --dest "$SVC" --object-path "$OBJ" \
    --method org.freedesktop.DBus.Properties.Set "$IFACE" Brightness "<$1>" >/dev/null 2>&1
}

clamp() { awk -v p="$1" -v f="$FLOOR" 'BEGIN{ if(p>100)p=100; if(p<f)p=f; printf "%d", p }'; }

cur=$(prop_get); [ -z "$cur" ] && cur=1.0
cur_pct=$(awk -v c="$cur" 'BEGIN{printf "%d", c*100 + 0.5}')

case "$1" in
  up)   new=$(clamp $((cur_pct + STEP))) ;;
  down) new=$(clamp $((cur_pct - STEP))) ;;
  set)  new=$(clamp "${2:-$cur_pct}") ;;
  get)  echo "$cur_pct"; exit 0 ;;
  *)    echo "usage: $0 {up|down|set <0-100>|get}" >&2; exit 1 ;;
esac

prop_set "$(awk -v p="$new" 'BEGIN{printf "%.2f", p/100}')"
