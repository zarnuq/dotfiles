#!/usr/bin/env python3
# Notification history for the eww widget.
#
# `dunstctl history` only works via `busctl` (a systemd tool absent on Void),
# so it always fails here. dunst's other actions use dbus-send and work fine.
# This queries the same dunst method directly with dbus-send and emits
# [{"app","summary","body"}] for the most recent notifications.

import json
import re
import subprocess
import sys

DEST = "org.freedesktop.Notifications"
PATH = "/org/freedesktop/Notifications"
METHOD = "org.dunstproject.cmd0.NotificationListHistory"
LIMIT = 5
KEYMAP = {"appname": "app", "summary": "summary", "body": "body"}

try:
    out = subprocess.run(
        ["dbus-send", "--session", "--print-reply",
         "--dest=" + DEST, PATH, METHOD],
        capture_output=True, text=True, timeout=5,
    ).stdout
except Exception:
    print("[]")
    sys.exit(0)

key_re = re.compile(r'^string "(.*)"$')
val_re = re.compile(r'^variant\s+string "(.*)"$')

notifs = []
cur = None
depth = 0          # nesting of `array [` blocks
key = None         # pending dict-entry key

for raw in out.splitlines():
    s = raw.strip()
    if s == "array [":
        depth += 1
        if depth == 2:                       # start of one notification dict
            cur = {"app": "Unknown", "summary": "No summary", "body": ""}
        continue
    if s == "]":
        if depth == 2 and cur is not None:
            notifs.append(cur)
            cur = None
        depth -= 1
        key = None
        continue
    if depth != 2 or cur is None:            # skip nested arrays (e.g. actions)
        continue
    if s.startswith("dict entry("):
        key = None
        continue
    m = key_re.match(s)
    if m and key is None:
        key = m.group(1)
        continue
    m = val_re.match(s)
    if m and key is not None:
        mapped = KEYMAP.get(key)
        if mapped:
            cur[mapped] = m.group(1).replace('\\"', '"')
        key = None

print(json.dumps(notifs[:LIMIT]))
