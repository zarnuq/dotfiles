#!/bin/bash

# Get audio info
get_audio() {
    sink_name=$(pactl info | grep "Default Sink" | cut -d ':' -f2- | xargs)
    
    volume=$(pactl get-sink-volume "$sink_name" 2>/dev/null | head -n1 | grep -o '[0-9]\+%' | head -1)
    muted=$(pactl get-sink-mute "$sink_name" 2>/dev/null | awk '{print $2}')
    
    description=$(pactl list sinks | awk -v sink="$sink_name" '
        $0 ~ "Name: "sink { in_sink=1 }
        in_sink && /Description:/ { print $0; exit }
    ' | cut -d ':' -f2- | xargs)
    
    cleaned=$(echo "$description" | sed -E \
        -e 's/\([^)]*\)//g' \
        -e 's/\b(Analog|HD|Audio|17h|19h|1ah|\/|Digital|Stereo|Mono|Controller|Family|Surround|Sink|Output|A2DP|Pro|Profile|HDMI)\b//Ig' \
        -e 's/ +/ /g' \
        -e 's/^ //' \
        -e 's/ $//')
    
    if [[ "$muted" == "yes" ]]; then
      echo "$cleaned  ${volume:-N/A}"
    else
      echo "$cleaned  ${volume:-N/A}"
    fi
}

get_mic() {
    source_name=$(pactl info | grep "Default Source" | cut -d ':' -f2- | xargs)
    
    volume=$(pactl get-source-volume "$source_name" 2>/dev/null | head -n1 | grep -o '[0-9]\+%' | head -1)
    muted=$(pactl get-source-mute "$source_name" 2>/dev/null | awk '{print $2}')
    
    if [[ "$muted" == "yes" ]]; then
      echo "${volume:-N/A}"
    else
        echo "^fg(f38ba8)${volume:-N/A}^fg()"
    fi
}


# Get CPU usage
get_cpu() {
    usage=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2 + $4)}')
    echo " $usage%"
}

# Get memory usage
get_mem() {
    used=$(free -m | awk '/Mem:/ { print $3 }')
    echo " ${used}MB"
}

# Get date/time
get_clock() {
    date=$(date '+%a %m/%d/%y')
    time=$(date '+%I:%M:%S %p')
    echo " $date  $time"
}

cpu=""
mem=""
clock=""
audio=""
mic=""
counter=0

# Polling loop
while true; do
    audio=$(get_audio)
    mic=$(get_mic)

    if (( counter % 1 == 0 )); then
        clock=$(get_clock)
    fi

    if (( counter % 2 == 0 )); then
        cpu=$(get_cpu)
    fi

    if (( counter % 5 == 0 )); then
        mem=$(get_mem)
    fi

    echo "$audio $mic|$cpu|$mem|$clock"
    sleep 1
    ((counter++))
done
