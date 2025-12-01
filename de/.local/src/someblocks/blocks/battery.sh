#!/bin/bash
if [ -d "/sys/class/power_supply/BAT0" ]; then
    cap=$(cat "/sys/class/power_supply/BAT0/capacity")
    stat=$(cat "/sys/class/power_supply/BAT0/status")
    case $stat in
        "Charging") icon="";;
        "Discharging") icon="";;
        "Full") icon="";;
        *) icon="";;
    esac
    echo "$icon $cap%"
fi
