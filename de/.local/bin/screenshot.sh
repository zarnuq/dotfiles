#!/bin/sh
filename="$HOME/Pictures/screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png"
grim -g "$(slurp)" "$filename" \
  && swappy -f "$filename" -o "$filename"

