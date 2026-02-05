#!/usr/bin/env python3
"""Calendar widget script - fetches and parses ICS calendar with recurring event support"""

import json
import os
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path

try:
    import icalendar
    import recurring_ical_events
except ImportError:
    print("[]")
    sys.exit(0)

CONFIG_FILE = Path.home() / ".config/eww/calendar.url"
CACHE_FILE = Path("/tmp/eww-calendar.ics")
CACHE_AGE = 300  # 5 minutes


def fetch_calendar():
    """Fetch ICS file, using cache if fresh enough."""
    if not CONFIG_FILE.exists():
        return None

    url = CONFIG_FILE.read_text().strip()
    if not url:
        return None

    # Check cache age
    now = time.time()
    cache_time = CACHE_FILE.stat().st_mtime if CACHE_FILE.exists() else 0

    if now - cache_time > CACHE_AGE:
        import urllib.request
        try:
            with urllib.request.urlopen(url, timeout=10) as response:
                CACHE_FILE.write_bytes(response.read())
        except Exception:
            if not CACHE_FILE.exists():
                return None

    if not CACHE_FILE.exists():
        return None

    return CACHE_FILE.read_bytes()


def parse_events(ics_data):
    """Parse ICS and expand recurring events."""
    # Rainbow colors by days from today
    DAY_COLORS = [
        "#f38ba8",  # red - today
        "#fab387",  # orange - tomorrow
        "#f9e2af",  # yellow
        "#a6e3a1",  # green
        "#89b4fa",  # blue
        "#b4befe",  # indigo
        "#cba6f7",  # violet
    ]

    try:
        calendar = icalendar.Calendar.from_ical(ics_data)
    except Exception:
        return []

    now = datetime.now()
    today = now.replace(hour=0, minute=0, second=0, microsecond=0)
    week_later = today + timedelta(days=7)

    # Get all events in the next 7 days (expanded from recurrences)
    events = recurring_ical_events.of(calendar).between(today, week_later)

    result = []
    for event in events:
        try:
            summary = str(event.get("SUMMARY", ""))
            location = str(event.get("LOCATION", "")) if event.get("LOCATION") else ""

            dtstart = event.get("DTSTART")
            dtend = event.get("DTEND")

            if not dtstart:
                continue

            start = dtstart.dt
            end = dtend.dt if dtend else None

            # Check if all-day event
            all_day = not isinstance(start, datetime)

            if all_day:
                start_dt = datetime.combine(start, datetime.min.time())
                time_str = "All day"
                event_date = start.strftime("%Y%m%d")
            else:
                start_dt = start
                event_date = start.strftime("%Y%m%d")

                # Format time in 12-hour format
                time_str = start.strftime("%-I:%M %p")
                if end and isinstance(end, datetime):
                    time_str += " - " + end.strftime("%-I:%M %p")

            # Determine day label
            event_day = start_dt.date() if isinstance(start_dt, datetime) else start
            today_date = today.date()
            tomorrow_date = (today + timedelta(days=1)).date()

            if event_day == today_date:
                day_label = "Today"
                days_from_today = 0
            elif event_day == tomorrow_date:
                day_label = "Tomorrow"
                days_from_today = 1
            else:
                day_label = start_dt.strftime("%A") if isinstance(start_dt, datetime) else start.strftime("%A")
                days_from_today = (event_day - today_date).days

            # Get color based on days from today (rainbow)
            color = DAY_COLORS[min(days_from_today, len(DAY_COLORS) - 1)]

            result.append({
                "summary": summary,
                "time": time_str,
                "day": day_label,
                "date": event_date,
                "location": location,
                "allday": all_day,
                "color": color,
                "_sort": start_dt.timestamp() if isinstance(start_dt, datetime) else datetime.combine(start, datetime.min.time()).timestamp()
            })
        except Exception:
            continue

    # Sort by date/time and limit to 10
    result.sort(key=lambda x: x["_sort"])
    for r in result:
        del r["_sort"]

    return result[:10]


def get_status():
    """Get calendar status."""
    if not CONFIG_FILE.exists():
        return "not configured"
    elif not CACHE_FILE.exists():
        return "no data"
    return "ok"


def main():
    if len(sys.argv) < 2:
        print("Usage: calendar.sh {events|status|refresh}")
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "events":
        ics_data = fetch_calendar()
        if ics_data:
            events = parse_events(ics_data)
            print(json.dumps(events))
        else:
            print("[]")

    elif cmd == "status":
        print(get_status())

    elif cmd == "refresh":
        if CACHE_FILE.exists():
            CACHE_FILE.unlink()
        ics_data = fetch_calendar()
        if ics_data:
            events = parse_events(ics_data)
            print(json.dumps(events))
        else:
            print("[]")

    else:
        print("Usage: calendar.sh {events|status|refresh}")
        sys.exit(1)


if __name__ == "__main__":
    main()
