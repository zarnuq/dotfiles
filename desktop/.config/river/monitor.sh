#!/bin/sh
wlr-randr --output DP-1 --mode 3440x1440@165.001007 --pos 2560,0 --adaptive-sync enabled --output HDMI-A-1 --mode 2560x1440@144.000000 --pos 0,0 --adaptive-sync enabled --output DP-2 --mode 1920x1080@165.003006 --pos 6000,0 --transform 270 --adaptive-sync enabled
gammastep -O 4000:4000 &

