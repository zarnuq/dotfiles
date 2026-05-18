#!/bin/sh
pkill -x pipewire-pulse
pkill -x wireplumber
pkill -x pipewire
pkill -x wl-clip-persist
sleep 0.1

pipewire &
pipewire-pulse &
wireplumber &
pgrep -x mpd || mpd &
wl-clip-persist -c regular &
dunst &
syncthing --no-browser &
gammastep -O 4000:4000 &
awww-daemon &
mpDris2 &
$HOME/.local/bin/eww.sh open &
dwlb &
someblocks -p | dwlb -status-stdin all &
kitty --class rmpc rmpc &
