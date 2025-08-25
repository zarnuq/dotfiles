#!/bin/bash

get_audio() {
   description=$(pactl list sinks | awk '
       /State: RUNNING/ { in_sink=1 }
       in_sink && /Description:/ { print $0; exit }
   ' | cut -d ':' -f2- | xargs)
   
   cleaned=$(echo "$description" | sed -E \
       -e 's/\([^)]*\)//g' \
       -e 's/\b(Analog|HD|Audio|17h|19h|1ah|\/|Digital|Stereo|Mono|Controller|Family|Surround|Sink|Output|A2DP|Pro|Profile|HDMI)\b//Ig' \
       -e 's/ +/ /g' \
       -e 's/^ //' \
       -e 's/ $//')
   
   echo "$cleaned"
}

get_vol() {
   volume=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | head -n1 | grep -o '[0-9]\+%' | head -1)
   echo "${volume:-N/A}"
}

get_mic() {
    local volume=$(pactl get-source-volume @DEFAULT_SOURCE@ | grep -o '[0-9]\+%' | head -1)
    local muted=$(pactl get-source-mute @DEFAULT_SOURCE@ | awk '{print $2}')
    
    if [[ "$muted" == "yes" ]]; then
        echo "${volume:-N/A}"
    else
        echo "^fg(f38ba8)${volume:-N/A}^fg()"
    fi
}

get_cpu() {
    usage=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2 + $4)}')
    echo " $usage%"
}

get_mem() {
    used=$(free -m | awk '/Mem:/ { print $3 }')
    echo " ${used}MB"
}

get_clock() {
    date=$(date '+%a %m/%d')
    time=$(date '+%I:%M %p')
    echo " $date  $time"
}

get_battery() {
    # Look for battery directory
    bat_path=$(find /sys/class/power_supply/ -maxdepth 1 -type d -name "BAT*" | head -n 1)
    if [ -n "$bat_path" ]; then
        cap=$(cat "$bat_path/capacity")
        stat=$(cat "$bat_path/status")

        case $stat in
            "Charging") icon="";;
            "Discharging") icon="";;
            "Full") icon="";;
            *) icon="";;
        esac

        echo "$icon $cap%"
    else
        # No battery found (desktop) → output nothing
        echo ""
    fi
}

cpu=""
mem=""
clock=""
mic=""
vol=""
audio=$(get_audio)
counter=0
# Polling loop
while true; do
    if [ -f /tmp/update_audio ]; then
        audio=$(get_audio)
        rm /tmp/update_audio
    fi
    vol=$(get_vol)
    mic=$(get_mic)
    clock=$(get_clock)
    cpu=$(get_cpu)
    mem=$(get_mem)

    echo "$audio $vol|$mic|$cpu|$mem|$clock"
    sleep 60
done
