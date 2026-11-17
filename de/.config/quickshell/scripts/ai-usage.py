#!/usr/bin/env python3
"""Quota-only agy/Kiro lookups; never submit a model prompt."""

import json
import math
import re
import subprocess
import sys
from datetime import datetime


def agy_usage():
    result = subprocess.run(
        ["agy", "-p", "/quota", "--output-format", "json"],
        capture_output=True, text=True, timeout=30, check=True,
    )
    groups = json.loads(result.stdout)["command"]["data"]["groups"]
    windows = []
    for group in groups:
        # These are separate shared quota pools, including agy's non-Gemini models.
        label = {"Gemini Models": "agy Gemini", "Claude and GPT models": "agy Claude/GPT"}.get(
            group["name"], "agy " + group["name"]
        )
        for bucket in sorted(group["buckets"], key=lambda b: b["window"] != "5h"):
            remaining = float(bucket["remaining_fraction"])
            resets_at = datetime.fromisoformat(bucket["reset_time"].replace("Z", "+00:00")).timestamp()
            if not math.isfinite(remaining) or not math.isfinite(resets_at):
                raise ValueError("Invalid quota window")
            windows.append({
                "name": label,
                "window": "7d" if bucket["window"] == "weekly" else bucket["window"],
                "used_percent": max(0, min(100, (1 - remaining) * 100)),
                "resets_at": resets_at,
            })
    if not windows:
        raise ValueError("No quota windows")
    return {"windows": windows}


def kiro_usage():
    # /usage is a client-side slash command: no model turn, no credits.
    result = subprocess.run(
        ["kiro-cli", "chat", "--no-interactive", "--agent-engine", "v2", "--trust-tools=",
         "--output-format", "stream-json", "/usage"],
        capture_output=True, text=True, timeout=60, check=True,
    )
    text = session = None
    for line in result.stdout.splitlines():
        event = json.loads(line)
        if event["type"] == "runFinished":
            text, session = event["data"]["finalText"], event["data"]["sessionId"]
    if session:
        # Every headless run is saved as a chat session; don't pile one up per poll.
        subprocess.run(["kiro-cli", "chat", "-d", session], capture_output=True, timeout=30)
    # "Estimated Usage | resets on 2026-12-01 | KIRO STUDENT\nCredits (0.00 of 1000 covered in plan), 0.0%"
    reset = re.search(r"resets on (\d{4}-\d{2}-\d{2})", text)
    used = re.search(r"Credits \(([\d.,]+) of ([\d.,]+)", text)
    used_credits, limit = (float(g.replace(",", "")) for g in used.groups())
    if limit <= 0:
        raise ValueError("No credit limit")
    return {"windows": [{
        "name": "Kiro",
        "window": "mo",
        "used_percent": max(0, min(100, used_credits / limit * 100)),
        "resets_at": datetime.fromisoformat(reset.group(1)).timestamp(),
    }]}


def main():
    provider = sys.argv[1] if len(sys.argv) == 2 else ""
    lookup = {"agy": agy_usage, "kiro": kiro_usage}.get(provider)
    if not lookup:
        raise SystemExit("usage: ai-usage.py agy|kiro")
    try:
        value = lookup()
    except (OSError, ValueError, KeyError, TypeError, AttributeError, subprocess.SubprocessError):
        value = {"error": "usage unavailable"}
    print(json.dumps(value, allow_nan=False))


if __name__ == "__main__":
    main()
