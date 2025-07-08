#!/bin/sh

# Function to get cleaned, friendly sink description
get_clean_sink() {
    sink_name=$(pactl info | grep "Default Sink" | cut -d ':' -f2- | xargs)

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

    # Output to Yambar
    echo "test|string|$cleaned"
    echo ""
}

# Initial output
get_clean_sink

# Listen for changes from PulseAudio/PipeWire
pactl subscribe | while read -r line; do
    if echo "$line" | grep -q "Event 'change' on sink"; then
        get_clean_sink
    elif echo "$line" | grep -q "Event 'new' on server"; then
        get_clean_sink
    elif echo "$line" | grep -q "Event 'change' on server"; then
        get_clean_sink
    elif echo "$line" | grep -q "Event 'change' on card"; then
        get_clean_sink
    fi
done

