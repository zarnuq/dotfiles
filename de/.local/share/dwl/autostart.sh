#!/bin/sh
#sh ~/.local/bin/monitor.sh &
export XCURSOR_THEME=Bibata-Modern-Classic
export XCURSOR_SIZE=24
export XDG_CURRENT_DESKTOP=dwl
export XDG_SESSION_DESKTOP=dwl
export XDG_SESSION_TYPE=wayland
export QT_QPA_PLATFORMTHEME=qt6ct
export QT_STYLE_OVERRIDE=kvantum

#autostart stuff
dunst &
copyq &
dwlb &
swww-daemon &
swww img "$(find ~/Pictures/bgs -type f \( -iname '*.jpg' -o -iname '*.png' \) | shuf -n1)" --transition-fps 144 --transition-type top --transition-duration 0 &
~/.local/share/dwlb/status.sh | dwlb -status-stdin all &
easyeffects --gapplication-service &
xremap ~/.config/xremap/config.yml &
#sh ~/.local/bin/screenshare.sh &
gammastep -O 4000:4000 &
kitty --class rmpc rmpc &
