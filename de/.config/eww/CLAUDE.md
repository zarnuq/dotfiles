# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

EWW (ElKowars Wacky Widgets) configuration using a multi-config architecture. Widgets are split into separate modules (`dash/` and `vpn/`) allowing independent eww instances.

## Commands

Launch all widgets:
```bash
~/.local/bin/eww.sh open
```

Close all widgets:
```bash
~/.local/bin/eww.sh close
```

Open only dashboard:
```bash
~/.local/bin/eww.sh dash
```

Toggle VPN widget:
```bash
~/.local/bin/eww.sh vpn
```

Direct eww commands for a specific module:
```bash
eww --config ~/.config/eww/dash open [window_name]
eww --config ~/.config/eww/vpn update vpn-expanded=true
eww --config ~/.config/eww/dash close-all
```

## Architecture

### Multi-Config Structure

```
eww/
├── dash/           # Dashboard module (clock, cpu, ram, disk, network, etc.)
│   ├── eww.yuck    # Widget definitions
│   └── eww.scss    # Styling
├── vpn/            # VPN selector module
│   ├── eww.yuck
│   └── eww.scss
└── scripts/
    └── vpn-manager.sh  # OpenVPN management script
```

Each directory is a separate eww config (`--config` flag). This allows independent widget groups.

### Widget Pattern

Widgets follow a consistent pattern:
1. `defpoll` - Data fetching with interval (e.g., `defpoll cpu-temp :interval "2s" "command"`)
2. `defwidget` - UI component using the polled variables
3. `defwindow` - Window placement, monitor, geometry, stacking

Example:
```yuck
(defpoll data :interval "2s" "some-command")
(defwidget mywidget [] (label :text data))
(defwindow mywindow :monitor 1 :geometry (...) :stacking "bottom" (mywidget))
```

### Data Sources

- **Built-in variables**: `EWW_CPU`, `EWW_RAM`, `EWW_DISK`
- **System files**: `/proc/net/dev`, `/sys/class/thermal/thermal_zone*/temp`
- **External tools**: `nvidia-smi`, `mpc`, `dunstctl`, `curl wttr.in`
- **State files**: `/tmp/eww-*.{pid,status,log}` for VPN state persistence

### Polling Intervals

- Fast (1s): time, network speeds, mpd status
- Medium (2s): CPU/GPU, temps, notifications
- Slow (60s+): uptime, weather (600s), updates (1800s)

## Monitor Detection

The launcher script (`eww.sh`) detects monitors via `wlr-randr`:
- If `DP-2` exists: uses monitor 1 (desktop)
- Otherwise: uses monitor 0 (laptop)

Window definitions have `:monitor 1` hardcoded - the `--screen` flag overrides this at launch.

## VPN Widget

Requires:
- VPN configs in `~/VPNs/*.ovpn`
- Sudoers entries for `openvpn` and `kill` (passwordless)

State managed via `/tmp/eww-openvpn.{pid,status,log}`.

## Dependencies

- eww (with GTK layer shell support)
- nvidia-smi (for GPU stats)
- mpc (MPD client)
- dunstctl (notification control)
- jq (JSON parsing)
- curl (weather API)
- wlr-randr (monitor detection)
- notify-send (notifications)
- openvpn + sudo (VPN widget)
