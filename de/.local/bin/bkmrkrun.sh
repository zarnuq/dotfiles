#!/bin/bash
choice=$(grep -v '^#' ~/.local/bin/bkmrk.txt | rofi -dmenu -p "Bookmarks:")
if [[ -n "$choice" ]]; then
  text=$(echo "$choice" | cut -d' ' -f1)
  wtype "$text"
fi

