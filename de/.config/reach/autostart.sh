#!/bin/sh
trap 'kill 0' EXIT TERM INT


pgrep -f "runsvdir $HOME/.local/sv" >/dev/null || \
	setsid runsvdir "$HOME/.local/sv" >/dev/null 2>&1 &
( sleep 2; $HOME/.local/bin/redshift.sh 4000 ) &
kitty --class rmpc rmpc &

dconf load /org/gnome/desktop/interface/ < "$HOME/.config/dconf/interface.dconf"
wait
