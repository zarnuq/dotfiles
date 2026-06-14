#!/bin/sh
pkill -f 'wl-paste --watch cliphist'
pkill -x mako
pkill -x dwlb
pkill -x someblocks
pkill -f wl-gammarelay-rs
pkill -x awww-daemon
pkill -x mpDris2
pkill -x eww
pkill -x swayidle
sleep 0.1

trap 'kill 0' EXIT TERM INT

dconf load /org/gnome/desktop/interface/ < "$HOME/.config/dconf/interface.dconf"

pgrep -f "runsvdir $HOME/.local/sv" >/dev/null || \
	setsid runsvdir "$HOME/.local/sv" >/dev/null 2>&1 &
bus="${DBUS_SESSION_BUS_ADDRESS#unix:path=}"
while [ ! -S "$bus" ]; do sleep 0.05; done

eww --config "$HOME/.config/eww" daemon --no-daemonize &
wl-paste --type text  --watch cliphist store &
wl-paste --type image --watch cliphist store &
mako &
swayidle -w timeout 300 'swaylock -f' &
( sleep 2; $HOME/.local/bin/redshift.sh 4000 ) &
awww-daemon &
$HOME/.local/bin/eww.sh open &
dwlb &
someblocks -p | dwlb -status-stdin all &
kitty --class rmpc rmpc &

wait
