#!/bin/bash
# Glyph tracks level (fa battery_4..battery_0); the whole block is wrapped in
# dwlb-style ^fg()^ markup so reach paints it red under 20% while discharging
# and green while on the charger (same mechanism mic.sh uses for the unmuted-mic
# warning). "Full" counts as charging here, matching quickshell's Battery.qml.
LOW=20
RED=f38ba8
GREEN=a6e3a1

if [ -d "/sys/class/power_supply/BAT0" ]; then
    cap=$(cat "/sys/class/power_supply/BAT0/capacity")
    stat=$(cat "/sys/class/power_supply/BAT0/status")
    case $stat in
        "Charging") icon="";;
        "Full")     icon="";;
        "Discharging")
            if   [ "$cap" -le 10 ]; then icon=""
            elif [ "$cap" -le 25 ]; then icon=""
            elif [ "$cap" -le 50 ]; then icon=""
            elif [ "$cap" -le 75 ]; then icon=""
            else                         icon=""
            fi
            ;;
        *) icon="";;
    esac

    if [ "$stat" = "Discharging" ] && [ "$cap" -lt "$LOW" ]; then
        echo "^fg($RED)$icon $cap%^fg()"
    elif [ "$stat" = "Charging" ] || [ "$stat" = "Full" ]; then
        echo "^fg($GREEN)$icon $cap%^fg()"
    else
        echo "$icon $cap%"
    fi
fi
