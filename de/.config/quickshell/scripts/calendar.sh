#!/usr/bin/env python3
"""Calendar widget script: fetch an ICS feed and list the next week's events.

Stdlib only (it used icalendar + recurring_ical_events from home-manager). The
parser covers what the feed — an Outlook calendar — actually uses: VEVENTs
with TZID'd, UTC or all-day DTSTART/DTEND, RRULE FREQ=DAILY/WEEKLY with
INTERVAL/BYDAY/UNTIL/COUNT/WKST, EXDATE, and RECURRENCE-ID overrides.
"""

import json
import re
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

CONFIG_FILE = Path.home() / ".config/quickshell/scripts/calendar.url"
CACHE_FILE = Path("/tmp/eww-calendar.ics")
CACHE_AGE = 300  # 5 minutes

# Outlook names zones the Windows way; zoneinfo wants IANA. An unknown name
# falls back to local time.
WINDOWS_TZ = {
    "Eastern Standard Time": "America/New_York",
    "Central Standard Time": "America/Chicago",
    "Mountain Standard Time": "America/Denver",
    "US Mountain Standard Time": "America/Phoenix",
    "Pacific Standard Time": "America/Los_Angeles",
    "GMT Standard Time": "Europe/London",
    "UTC": "UTC",
}
DAYS = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]


def fetch_calendar():
    """Fetch ICS file, using cache if fresh enough."""
    if not CONFIG_FILE.exists():
        return None

    url = CONFIG_FILE.read_text().strip()
    if not url:
        return None

    cache_time = CACHE_FILE.stat().st_mtime if CACHE_FILE.exists() else 0
    if time.time() - cache_time > CACHE_AGE:
        import urllib.request
        try:
            with urllib.request.urlopen(url, timeout=10) as response:
                CACHE_FILE.write_bytes(response.read())
        except Exception:
            pass

    return CACHE_FILE.read_text(errors="replace") if CACHE_FILE.exists() else None


def zone(tzid):
    try:
        return ZoneInfo(WINDOWS_TZ.get(tzid, tzid)) if tzid else None
    except Exception:
        return None


def unescape(v):
    return re.sub(r"\\(.)", lambda m: "\n" if m.group(1) in "nN" else m.group(1), v)


def vevents(text):
    """VEVENT blocks as {NAME: (params, value)}; EXDATE collects every line."""
    events, cur = [], None
    for line in re.sub(r"\r?\n[ \t]", "", text).splitlines():   # unfold first
        if line == "BEGIN:VEVENT":
            cur = {"EXDATE": []}
        elif line == "END:VEVENT" and cur is not None:
            events.append(cur)
            cur = None
        elif cur is not None and ":" in line:
            head, value = line.split(":", 1)
            name, *ps = head.split(";")
            params = {k: v.strip('"') for k, _, v in (p.partition("=") for p in ps)}
            if name == "EXDATE":
                cur["EXDATE"] += [(params, v) for v in value.split(",")]
            else:
                cur[name] = (params, value)
    return events


def when(prop):
    """(naive wall-clock datetime, tzinfo or None for local, all_day)."""
    params, v = prop
    if params.get("VALUE") == "DATE" or len(v) == 8:
        return datetime.strptime(v[:8], "%Y%m%d"), None, True
    dt = datetime.strptime(v[:15], "%Y%m%dT%H%M%S")
    return dt, timezone.utc if v.endswith("Z") else zone(params.get("TZID")), False


def instant(dt, tz, *_):
    """The aware moment a wall-clock time in `tz` names (naive = local)."""
    return dt.replace(tzinfo=tz) if tz else dt.astimezone()


def occurrences(start, tz, rule, limit):
    """Wall-clock starts of a recurring event, from DTSTART up to `limit`."""
    r = dict(p.partition("=")[::2] for p in rule.split(";"))
    freq, interval = r.get("FREQ"), int(r.get("INTERVAL", 1))
    if freq not in ("DAILY", "WEEKLY"):
        # ponytail: only the frequencies the feed uses; anything else shows its
        # first occurrence only. Add MONTHLY/YEARLY here if one ever appears.
        yield start
        return
    byday = {DAYS.index(d[-2:]) for d in r.get("BYDAY", DAYS[start.weekday()]).split(",")}
    week0 = start.date() - timedelta((start.weekday() - DAYS.index(r.get("WKST", "MO"))) % 7)
    until = instant(*when(({}, r["UNTIL"]))) if "UNTIL" in r else None
    count, n, day = int(r.get("COUNT", 0)), 0, start
    while day <= limit:
        if freq == "DAILY":
            hit = (day.date() - start.date()).days % interval == 0
        else:
            hit = day.weekday() in byday and (day.date() - week0).days // 7 % interval == 0
        if hit:
            if until and instant(day, tz) > until:
                return
            n += 1
            if count and n > count:
                return
            yield day
        day += timedelta(days=1)


def fmt(dt):
    return dt.strftime("%-I:%M %p")


def parse_events(ics, now=None):
    """The next 14 days' events (including ones already under way)."""
    today = datetime.combine((now or datetime.now()).date(), datetime.min.time()).astimezone()
    week_later = today + timedelta(days=14)
    limit = (week_later + timedelta(days=1)).replace(tzinfo=None)   # wall-clock bound, any zone

    events = vevents(ics)
    # Occurrences of a series that an override VEVENT replaces.
    moved = {(e.get("UID", ({}, ""))[1], instant(*when(e["RECURRENCE-ID"])))
             for e in events if "RECURRENCE-ID" in e}

    result = []
    for e in events:
        try:
            if "DTSTART" not in e:
                continue
            start, tz, all_day = when(e["DTSTART"])
            if "DTEND" in e:
                length = when(e["DTEND"])[0] - start
            else:
                length = timedelta(days=1) if all_day else timedelta(0)
            uid = e.get("UID", ({}, ""))[1]
            override = "RECURRENCE-ID" in e
            skip = {instant(*when(x)) for x in e["EXDATE"]}

            series = occurrences(start, tz, e["RRULE"][1], limit) if "RRULE" in e and not override else [start]
            for s in series:
                at = instant(s, tz)
                if at in skip or (not override and (uid, at) in moved):
                    continue
                if at >= week_later or (at + length <= today and at < today):
                    continue

                local = at.astimezone()
                if all_day:
                    time_str = "All day"
                else:
                    time_str = fmt(local)
                    if "DTEND" in e:
                        time_str += " - " + fmt((at + length).astimezone())

                # The day offset Calendar.qml colours by (a rainbow of Theme
                # tokens, today red through violet).
                days_from_today = (local.date() - today.date()).days
                # A multi-day event that began more than a week ago: the old
                # 7-entry colour table raised IndexError on this and the event
                # was dropped. Kept, so the agenda lists what it always has.
                if days_from_today < -7:
                    continue

                result.append((at.timestamp(), {
                    "summary": unescape(e.get("SUMMARY", ({}, ""))[1]),
                    "time": time_str,
                    # A weekday name repeats past a week, so the date takes over there.
                    "day": {0: "Today", 1: "Tomorrow"}.get(days_from_today)
                           or local.strftime("%A" if days_from_today < 7 else "%a %b %-d"),
                    "location": unescape(e.get("LOCATION", ({}, ""))[1]),
                    "days_from_today": days_from_today,
                }))
        except Exception:
            continue

    # Sorted by start; the 14-day window bounds it and the card scrolls.
    result.sort(key=lambda r: r[0])
    return [r for _, r in result]


def get_status():
    """Get calendar status."""
    if not CONFIG_FILE.exists():
        return "not configured"
    elif not CACHE_FILE.exists():
        return "no data"
    return "ok"


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""

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
