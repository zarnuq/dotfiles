#!/bin/sh
pkill -f 'wl-paste --watch cliphist'
pkill -x swayidle
sleep 0.1

trap 'kill 0' EXIT TERM INT

dconf load /org/gnome/desktop/interface/ < "$HOME/.config/dconf/interface.dconf"

pgrep -f "runsvdir $HOME/.local/sv" >/dev/null || \
	setsid runsvdir "$HOME/.local/sv" >/dev/null 2>&1 &
wl-paste --type text  --watch cliphist store &
wl-paste --type image --watch cliphist store &
swayidle -w timeout 300 'swaylock -f' &
( sleep 2; $HOME/.local/bin/redshift.sh 4000 ) &
kitty --class rmpc rmpc &

wait
