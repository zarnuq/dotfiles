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
import re
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


# ── Week grid ────────────────────────────────────────────────────────────────
# `week [offset]` feeds CalendarWeek.qml. Unlike `events` (a flat agenda of
# pre-formatted strings for the sidebar), this emits *geometry* — a day index
# plus minutes-from-midnight — and leaves all formatting to QML.
# `offset` is in weeks from the current one: -1 = last week, +1 = next.

# Per-course colours, assigned by hashing the course key so a class keeps the
# same colour across weeks and restarts without any state to persist.
EVENT_COLORS = [
    "#89b4fa",  # blue
    "#a6e3a1",  # green
    "#f9e2af",  # yellow
    "#fab387",  # peach
    "#cba6f7",  # mauve
    "#94e2d5",  # teal
    "#f38ba8",  # red
    "#b4befe",  # lavender
    "#74c7ec",  # sapphire
    "#f5c2e7",  # pink
    "#eba0ac",  # maroon
    "#89dceb",  # sky
]


def course_key(summary):
    """Collapse an event title to the course that owns it, for colouring.

    Canvas trails the course in brackets ("Quiz 1 ... [CAS 100A]"), Outlook
    uses a " - " section suffix ("CYBER 262 - LEC"). Anything else colours by
    its own title, which just means one-off events get their own colour.
    """
    m = re.search(r"\[([^\]]+)\]\s*$", summary)
    if m:
        return m.group(1).strip()
    return summary.split(" - ")[0].strip() or summary


def color_map(occurrences):
    """Assign each course in view a colour from the palette.

    Scoped to the *visible week*, not the whole feed. Two rejected alternatives:
    hashing the course key collided three times on eight courses, and indexing
    the feed's full course list wraps the palette (a year of courses is well
    over len(EVENT_COLORS)) and collides again. A single week holds far fewer
    courses than the palette, so sorting the keys present here is collision-free
    where it actually matters — on screen. It is stable week to week in practice
    because a semester's weekly schedule repeats.
    """
    keys = set()
    for ev in occurrences:
        try:
            summary = str(ev.get("SUMMARY", "")).strip()
            if summary:
                keys.add(course_key(summary))
        except Exception:
            continue
    return {k: EVENT_COLORS[i % len(EVENT_COLORS)] for i, k in enumerate(sorted(keys))}


def to_local(dt):
    """Convert to local time and drop tzinfo, so all arithmetic stays naive."""
    if dt.tzinfo is not None:
        dt = dt.astimezone()
    return dt.replace(tzinfo=None)


def fmt_time(dt):
    return dt.strftime("%-I:%M %p")


def build_week(ics_data, offset=0):
    """Build the full grid payload. Always returns a valid structure — with no
    ICS at all the day headers still render, just with nothing in them."""
    now = datetime.now()
    today = now.replace(hour=0, minute=0, second=0, microsecond=0)
    # Sunday-anchored to match Outlook's week view. weekday(): Mon=0 .. Sun=6.
    week_start = today - timedelta(days=(today.weekday() + 1) % 7) + timedelta(weeks=offset)
    week_end = week_start + timedelta(days=7)

    days = []
    for i in range(7):
        d = week_start + timedelta(days=i)
        days.append({
            "date": d.strftime("%Y-%m-%d"),
            "dow": d.strftime("%A"),
            "dom": d.day,
            "month": d.strftime("%b"),
            "today": d.date() == today.date(),
        })

    last = week_end - timedelta(days=1)
    if week_start.month == last.month:
        label = "%s %d – %d, %d" % (week_start.strftime("%B"), week_start.day, last.day, last.year)
    else:
        label = "%s %d – %s %d, %d" % (week_start.strftime("%B"), week_start.day,
                                       last.strftime("%B"), last.day, last.year)

    allday, timed = [], []
    occurrences = []
    colors = {}
    if ics_data:
        try:
            calendar = icalendar.Calendar.from_ical(ics_data)
            occurrences = recurring_ical_events.of(calendar).between(week_start, week_end)
            colors = color_map(occurrences)
        except Exception:
            occurrences = []

    for event in occurrences:
        try:
            summary = str(event.get("SUMMARY", "")).strip() or "(no title)"
            location = str(event.get("LOCATION", "")) if event.get("LOCATION") else ""
            color = colors.get(course_key(summary), EVENT_COLORS[0])

            dtstart = event.get("DTSTART")
            if not dtstart:
                continue
            start = dtstart.dt
            dtend = event.get("DTEND")
            end = dtend.dt if dtend else None

            # All-day: DTSTART is a bare date. DTEND is exclusive, and a missing
            # one means a single day.
            if not isinstance(start, datetime):
                if end is not None and not isinstance(end, datetime):
                    end_day = end
                else:
                    end_day = start + timedelta(days=1)
                first = (start - week_start.date()).days
                span = max((end_day - start).days, 1)
                for k in range(max(first, 0), min(first + span, 7)):
                    allday.append({
                        "day": k, "summary": summary,
                        "location": location, "color": color,
                    })
                continue

            s = to_local(start)
            e = to_local(end) if isinstance(end, datetime) else s + timedelta(hours=1)
            if e <= s:
                e = s + timedelta(minutes=30)

            # Split across day columns so an event crossing midnight (or a
            # multi-day timed event) renders as a clipped block in each day.
            cur = s
            while cur < e:
                day_start = cur.replace(hour=0, minute=0, second=0, microsecond=0)
                day_end = day_start + timedelta(days=1)
                seg_end = min(e, day_end)
                idx = (day_start.date() - week_start.date()).days
                if 0 <= idx < 7:
                    sm = int((cur - day_start).total_seconds() // 60)
                    em = int((seg_end - day_start).total_seconds() // 60)
                    timed.append({
                        "day": idx,
                        "start": sm,
                        # Floor the height so a 5-minute event stays readable.
                        "end": min(1440, max(em, sm + 20)),
                        "summary": summary,
                        "location": location,
                        "color": color,
                        "time": fmt_time(cur) + " – " + fmt_time(seg_end),
                    })
                cur = day_end
        except Exception:
            continue

    timed.sort(key=lambda t: (t["day"], t["start"]))
    allday.sort(key=lambda a: (a["day"], a["summary"]))

    # Fit the vertical span to the week's actual events, but never show less
    # than a normal working day — a sparse week shouldn't render as two rows.
    if timed:
        min_hour = min(min(t["start"] for t in timed) // 60, 8)
        max_hour = max(-(-max(t["end"] for t in timed) // 60), 20)
    else:
        min_hour, max_hour = 8, 20

    out = {
        "label": label,
        "offset": offset,
        "days": days,
        "allday": allday,
        "timed": timed,
        "min_hour": max(0, min_hour),
        "max_hour": min(24, max_hour),
        "now": None,
    }
    now_idx = (today.date() - week_start.date()).days
    if 0 <= now_idx < 7:
        out["now"] = {"day": now_idx, "min": now.hour * 60 + now.minute}
    return out


def main():
    if len(sys.argv) < 2:
        print("Usage: calendar.sh {events|week [offset]|status|refresh}")
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "events":
        ics_data = fetch_calendar()
        if ics_data:
            events = parse_events(ics_data)
            print(json.dumps(events))
        else:
            print("[]")

    elif cmd == "week":
        offset = 0
        if len(sys.argv) > 2:
            try:
                offset = int(sys.argv[2])
            except ValueError:
                offset = 0
        print(json.dumps(build_week(fetch_calendar(), offset)))

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
        print("Usage: calendar.sh {events|week [offset]|status|refresh}")
        sys.exit(1)


if __name__ == "__main__":
    main()
