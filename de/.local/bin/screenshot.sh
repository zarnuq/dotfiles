#!/bin/sh

case "$1" in
    section)
        filename="$HOME/Pictures/screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png"
        grim -g "$(slurp)" "$filename" \
          && satty --filename="$filename" --output-filename="$filename"
        ;;
    DP-1|DP-2|DP-3|HDMI-1|HDMI-2)
        filename="$HOME/Pictures/screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png"
        grim -o "$1" "$filename" \
          && satty --filename="$filename" --output-filename="$filename"
        ;;
    *)
        exit 1
        ;;
esac
