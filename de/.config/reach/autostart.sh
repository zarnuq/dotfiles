#!/bin/sh
trap 'kill 0' EXIT TERM INT

runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime/bus"
pgrep -f "runsvdir $HOME/.local/sv" >/dev/null || \
	setsid runsvdir "$HOME/.local/sv" >/dev/null 2>&1 &
bus="$runtime/bus"
while [ ! -S "$bus" ]; do sleep 0.05; done

( sleep 2; $HOME/.local/bin/redshift.sh 4000 ) &
kitty --class rmpc rmpc &

dconf load /org/gnome/desktop/interface/ < "$HOME/.config/dconf/interface.dconf"
wait
