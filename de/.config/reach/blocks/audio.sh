#!/bin/bash
default=$(pactl get-default-sink 2>/dev/null)
[ -z "$default" ] && exit
pactl list sinks | awk -v name="$default" '
    /Name:/ { in_sink = ($2 == name) }
    in_sink && /Description:/ { print $0; exit }
' | cut -d ':' -f2- | xargs | sed -E \
    -e 's/\([^)]*\)//g' \
    -e 's/\b(Analog|HD|Audio|17h|19h|1ah|\/|Digital|Stereo|Mono|Controller|Family|Surround|Sink|Output|A2DP|Pro|Profile|HDMI)\b//Ig' \
    -e 's/ +/ /g' \
    -e 's/^ //' \
    -e 's/ $//'
