#!/bin/sh
#
# ss       region -> clipboard
# section  region -> file, then satty
# region   region -> file
# <output> whole output -> file, then satty   (any name grim accepts)
#
# Every branch EXITS NON-ZERO WHEN THE CAPTURE DID NOT HAPPEN, which callers
# depend on: both the Super+S chord and the quickshell screenshot menu append
# `&& notify-send …`, and a cancelled selection has to say nothing rather than
# claim a save.

dest() {
    printf '%s/Pictures/screenshot-%s.png' "$HOME" "$(date +'%Y-%m-%d_%H-%M-%S')"
}

case "$1" in
    ss)
        # slurp is guarded separately, and the capture no longer runs as a
        # pipeline: a shell pipeline reports its LAST command, so the old
        # `grim … | wl-copy` returned wl-copy's status and the caller's `&&`
        # was testing the paste rather than the capture — cancel a selection
        # and it still announced "Quick capture saved!".
        geom=$(slurp) || exit 1
        tmp=$(mktemp) || exit 1
        grim -g "$geom" "$tmp" || { rm -f "$tmp"; exit 1; }
        wl-copy --type image/png < "$tmp"
        status=$?
        rm -f "$tmp"
        exit "$status"
        ;;
    section)
        geom=$(slurp) || exit 1
        filename=$(dest)
        grim -g "$geom" "$filename" \
          && satty --filename="$filename" --output-filename="$filename"
        ;;
    region)
        geom=$(slurp) || exit 1
        filename=$(dest)
        grim -g "$geom" "$filename"
        ;;
    "")
        exit 1
        ;;
    *)
        # Any output grim knows. This was a fixed allowlist
        # (DP-1|DP-2|DP-3|eDP-1|HDMI-1|HDMI-2) that omitted DP-5 — the laptop's
        # stand monitor in monitors/docked.zon — so that head fell through to
        # the catch-all and could not be captured at all. grim rejects a name
        # it does not know, and says which.
        filename=$(dest)
        grim -o "$1" "$filename" \
          && satty --filename="$filename" --output-filename="$filename"
        ;;
esac
