#!/bin/sh
pkill -x pipewire-pulse
pkill -x wireplumber
pkill -x pipewire
pkill -f 'wl-paste --watch cliphist'
pkill -x mako
pkill -x dwlb
pkill -x someblocks
pkill -f wl-gammarelay-rs
pkill -x awww-daemon
pkill -x mpDris2
pkill -x mpd
pkill -x syncthing
pkill -x eww
pkill -x emacs
pkill -x swayidle 
sleep 0.1

trap 'kill 0' EXIT TERM INT

dconf load /org/gnome/desktop/interface/ < "$HOME/.config/dconf/interface.dconf"
pipewire &
pipewire-pulse &
wireplumber &
eww --config "$HOME/.config/eww" daemon --no-daemonize &
mpd --no-daemon &
wl-paste --type text  --watch cliphist store &
wl-paste --type image --watch cliphist store &
syncthing --no-browser &
mako &
swayidle -w timeout 300 'swaylock -f' &
wl-gammarelay-rs &
( sleep 1; $HOME/.local/bin/redshift.sh 4000 ) &   # restore warm night-light
awww-daemon &
mpDris2 &
$HOME/.local/bin/eww.sh open &
dwlb &
someblocks -p | dwlb -status-stdin all &
kitty --class rmpc rmpc &
emacs --fg-daemon &

wait
