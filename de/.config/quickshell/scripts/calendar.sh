#!/usr/bin/env python3
"""Calendar widget script - fetches and parses ICS calendar with recurring event support"""

import glob
import os
import sys

# icalendar / recurring_ical_events come from home-manager, which installs them
# under the nix profile's *current* python. Glob the version out rather than
# pinning it: this was hardcoded to python3.13, and when nix moved to 3.14 the
# imports started failing silently (every command just returned "[]").
# Prefer the running interpreter's own version, then fall back to any other.
_mine = "python%d.%d" % sys.version_info[:2]
_paths = sorted(glob.glob(os.path.expanduser("~/.nix-profile/lib/python*/site-packages")),
                key=lambda p: (_mine not in p, p))
for _p in reversed(_paths):
    sys.path.insert(0, _p)
if _paths:
    os.environ.setdefault("PYTHONPATH", os.pathsep.join(_paths))

import json
import time
from datetime import datetime, timedelta
from pathlib import Path

try:
    import icalendar
    import recurring_ical_events
except ImportError:
    print("[]")
    sys.exit(0)

CONFIG_FILE = Path.home() / ".config/quickshell/scripts/calendar.url"
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
    try:
        calendar = icalendar.Calendar.from_ical(ics_data)
    except Exception:
        return []

    now = datetime.now()
    today = now.replace(hour=0, minute=0, second=0, microsecond=0)
    today_date = today.date()
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

            # An all-day event's DTSTART is a date; normalise it to midnight so
            # everything below handles one type.
            if isinstance(start, datetime):
                start_dt = start
                # Format time in 12-hour format
                time_str = start.strftime("%-I:%M %p")
                if end and isinstance(end, datetime):
                    time_str += " - " + end.strftime("%-I:%M %p")
            else:
                start_dt = datetime.combine(start, datetime.min.time())
                time_str = "All day"

            # Day label, and the day offset Calendar.qml colours by (a rainbow
            # of Theme tokens, today red through violet).
            days_from_today = (start_dt.date() - today_date).days
            if days_from_today == 0:
                day_label = "Today"
            elif days_from_today == 1:
                day_label = "Tomorrow"
            else:
                day_label = start_dt.strftime("%A")

            # A multi-day event that began more than a week ago: the old
            # 7-entry colour table raised IndexError on this and the event was
            # dropped. Kept, so the agenda lists exactly what it always has.
            if days_from_today < -7:
                continue

            result.append({
                "summary": summary,
                "time": time_str,
                "day": day_label,
                "location": location,
                "days_from_today": days_from_today,
                "_sort": start_dt.timestamp(),
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

    if cmd == "status":
        print(get_status())

    elif cmd in ("events", "refresh"):
        # refresh = events with the cache thrown away first, so it prints the
        # same JSON (Calendar.qml's refresh button reads it directly).
        if cmd == "refresh" and CACHE_FILE.exists():
            CACHE_FILE.unlink()
        ics_data = fetch_calendar()
        print(json.dumps(parse_events(ics_data)) if ics_data else "[]")

    else:
        print("Usage: calendar.sh {events|status|refresh}")
        sys.exit(1)


if __name__ == "__main__":
    main()
