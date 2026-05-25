#!/bin/sh
# Night-light temperature for all outputs via wl-gammarelay-rs (D-Bus session bus).
#   redshift.sh        toggle 4000K <-> 6500K   (Mod+Alt+Up)
#   redshift.sh <K>    set absolute Kelvin

get() {
  gdbus call --session -d rs.wl-gammarelay -o / \
    -m org.freedesktop.DBus.Properties.Get rs.wl.gammarelay Temperature \
    | grep -oE '[0-9]+' | tail -1     # tail: skip the "16" in "uint16"
}
put() {
  gdbus call --session -d rs.wl-gammarelay -o / \
    -m org.freedesktop.DBus.Properties.Set rs.wl.gammarelay Temperature "<uint16 $1>"
}

if [ -n "$1" ]; then
  put "$1"
else
  cur=$(get); [ "${cur:-6500}" -le 5000 ] && put 6500 || put 4000
fi
