#!/bin/sh
pkill -x pipewire-pulse
pkill -x wireplumber
pkill -x pipewire
pkill -f 'wl-paste --watch cliphist'
pkill -x mako
pkill -x dwlb
pkill -x someblocks
pkill -x gammastep
pkill -x awww-daemon
pkill -x mpDris2
pkill -x mpd
pkill -x syncthing
pkill -x eww
pkill -x emacs
sleep 0.1

trap 'kill 0' EXIT TERM INT

pipewire &
pipewire-pulse &
wireplumber &
eww --config "$HOME/.config/eww/dash" daemon --no-daemonize &
mpd --no-daemon &
wl-paste --type text  --watch cliphist store &
wl-paste --type image --watch cliphist store &
syncthing --no-browser &
mako &
gammastep -O 4000:4000 &
awww-daemon &
mpDris2 &
$HOME/.local/bin/eww.sh open &
dwlb &
someblocks -p | dwlb -status-stdin all &
kitty --class rmpc rmpc &
emacs --fg-daemon &

wait
