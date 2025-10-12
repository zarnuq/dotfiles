#!/bin/sh
filename="$HOME/Pictures/screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png"
grim -o DP-2 "$filename" \
  && satty --filename="$filename" --output-filename="$filename"

