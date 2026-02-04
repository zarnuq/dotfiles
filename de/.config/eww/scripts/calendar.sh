#!/bin/bash

# Calendar widget script - fetches and parses ICS calendar
# Config: Put your ICS URL in ~/.config/eww/calendar.url

CONFIG_FILE="$HOME/.config/eww/calendar.url"
CACHE_FILE="/tmp/eww-calendar.ics"
CACHE_AGE=300  # Refresh every 5 minutes

fetch_calendar() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "[]"
        return
    fi

    local url
    url=$(cat "$CONFIG_FILE" | tr -d '[:space:]')

    if [[ -z "$url" ]]; then
        echo "[]"
        return
    fi

    # Check cache age
    local now
    now=$(date +%s)
    local cache_time=0

    if [[ -f "$CACHE_FILE" ]]; then
        cache_time=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
    fi

    if (( now - cache_time > CACHE_AGE )); then
        curl -s "$url" > "$CACHE_FILE" 2>/dev/null
    fi

    if [[ ! -f "$CACHE_FILE" ]]; then
        echo "[]"
        return
    fi

    parse_ics
}

parse_ics() {
    local today tomorrow
    today=$(date +%Y%m%d)
    tomorrow=$(date -d "+1 day" +%Y%m%d)
    local today_ts=$(date +%s)
    local week_later=$((today_ts + 7*24*60*60))

    awk -v today="$today" -v tomorrow="$tomorrow" -v now_ts="$today_ts" -v week_ts="$week_later" '
    BEGIN {
        RS = "BEGIN:VEVENT"
        FS = "\n"
        first = 1
        printf "["
    }

    NR > 1 {
        summary = ""
        dtstart = ""
        dtend = ""
        location = ""
        all_day = 0

        for (i = 1; i <= NF; i++) {
            line = $i
            # Handle line continuations
            gsub(/\r/, "", line)

            if (line ~ /^SUMMARY/) {
                sub(/^SUMMARY[^:]*:/, "", line)
                summary = line
            }
            else if (line ~ /^DTSTART/) {
                if (line ~ /VALUE=DATE:/) {
                    all_day = 1
                    sub(/^DTSTART[^:]*:/, "", line)
                    dtstart = line
                } else {
                    sub(/^DTSTART[^:]*:/, "", line)
                    dtstart = line
                }
            }
            else if (line ~ /^DTEND/) {
                sub(/^DTEND[^:]*:/, "", line)
                dtend = line
            }
            else if (line ~ /^LOCATION/) {
                sub(/^LOCATION[^:]*:/, "", line)
                location = line
            }
        }

        if (summary == "" || dtstart == "") next

        # Parse date - handle both YYYYMMDD and YYYYMMDDTHHMMSS formats
        if (length(dtstart) >= 8) {
            event_date = substr(dtstart, 1, 8)

            # Check if event is today, tomorrow, or within a week
            if (event_date >= today) {
                # Format time
                time_str = ""
                if (all_day) {
                    time_str = "All day"
                } else if (length(dtstart) >= 15) {
                    hour = substr(dtstart, 10, 2)
                    min = substr(dtstart, 12, 2)
                    # Convert to 12-hour format
                    h = int(hour)
                    ampm = "AM"
                    if (h >= 12) { ampm = "PM"; if (h > 12) h -= 12 }
                    if (h == 0) h = 12
                    time_str = sprintf("%d:%s %s", h, min, ampm)

                    if (length(dtend) >= 15) {
                        ehour = substr(dtend, 10, 2)
                        emin = substr(dtend, 12, 2)
                        eh = int(ehour)
                        eampm = "AM"
                        if (eh >= 12) { eampm = "PM"; if (eh > 12) eh -= 12 }
                        if (eh == 0) eh = 12
                        time_str = time_str " - " sprintf("%d:%s %s", eh, emin, eampm)
                    }
                }

                # Determine day label
                day_label = ""
                if (event_date == today) {
                    day_label = "Today"
                } else if (event_date == tomorrow) {
                    day_label = "Tomorrow"
                } else {
                    # Format as weekday
                    cmd = "date -d " event_date " +%A 2>/dev/null"
                    cmd | getline day_label
                    close(cmd)
                }

                # Escape quotes in strings
                gsub(/"/, "\\\"", summary)
                gsub(/"/, "\\\"", location)
                gsub(/\\/, "\\\\", summary)
                gsub(/\\/, "\\\\", location)

                if (!first) printf ","
                first = 0

                printf "{\"summary\":\"%s\",\"time\":\"%s\",\"day\":\"%s\",\"date\":\"%s\",\"location\":\"%s\",\"allday\":%s}",
                    summary, time_str, day_label, event_date, location, (all_day ? "true" : "false")
            }
        }
    }

    END {
        printf "]"
    }
    ' "$CACHE_FILE" 2>/dev/null | jq -c 'sort_by(.date, .time) | .[0:10]' 2>/dev/null || echo "[]"
}

get_status() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "not configured"
    elif [[ ! -f "$CACHE_FILE" ]]; then
        echo "no data"
    else
        echo "ok"
    fi
}

case "$1" in
    events)
        fetch_calendar
        ;;
    status)
        get_status
        ;;
    refresh)
        rm -f "$CACHE_FILE"
        fetch_calendar
        ;;
    *)
        echo "Usage: $0 {events|status|refresh}"
        exit 1
        ;;
esac
