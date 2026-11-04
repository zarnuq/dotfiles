---
name: ydotool
description: Use when driving or testing GUI applications on Miles's local Wayland desktop (River/Reach, Quickshell) with real keyboard and mouse input, such as LibreOffice, Obsidian and Obsidian plugins, GTK or Qt apps, menus, dialogs, spreadsheets, drags, or when screenshots, recordings, widget coordinates or desktop shortcuts are needed on this machine.
---

# Miles's desktop control

Machine-specific: River 0.4.8 with the Reach window manager, Quickshell shell, Nix ydotool 1.0.4, runit (not systemd). Do not substitute `riverctl`, Sway, Hyprland or X11 tools.

## Readiness

```sh
python3 <skill-dir>/scripts/inspect_desktop.py          # binaries, uinput, socket; emits no input
python3 <skill-dir>/scripts/inspect_desktop.py --state  # one Reach snapshot: outputs, desktops, titles, "mod"
```

`connected_socket` in the report is the authority; export it as `YDOTOOL_SOCKET` (normally `/run/ydotoold/socket`, from the [runit service](runit/README.md)). Call `/home/miles/.nix-profile/bin/ydotool` by absolute path; agent shells can lack Nix on PATH. If the inspector fails, report the missing device, socket or permission and stop sending input. Starting daemons, loading uinput and changing permissions are setup work the user must ask for.

## Choose how to navigate

Use the first option that works for the step:

1. **App API for setup and assertions.** Obsidian: `obsidian eval code=...`. Files: inspect saved output. Not for the interaction under test.
2. **AT-SPI for locating and verifying** (LibreOffice, GTK, Qt): `/usr/bin/python3 <skill-dir>/scripts/ui.py` finds widgets by name, clicks their centers, reads focus, text, formatting runs and spreadsheet cells. Read [references/atspi.md](references/atspi.md) before first use: window origins and popup limits matter.
3. **Keyboard** for menus, dialogs and anything with a shortcut: Alt+letter opens menus, arrows and Enter walk them, Tab moves through dialogs, Escape closes.
4. **Screenshot coordinates** last: `grim` a frame, read the pixel, click with the scale correction below.

Real input (ydotool) is for the behaviour being tested. Verify every step with state (AT-SPI, `obsidian eval`, saved files), and use screenshots for what state cannot show.

## Core loop

1. **Confirm focus** right before each input burst with `ui.py apps` (`| active`) or the purple `#cba6f7` border in a screenshot. Do not use Reach `--state` titles: they did not follow focus changes. To move focus: hover or click the window (sloppy focus), Super+J/K through the stack, or Super+digit for a desktop. See [scripting.md](references/scripting.md#changing-focus). Input goes to whatever is focused, including Miles's terminal. If he is typing there, wait. When you finish, give focus back to the window that had it.
2. **Act in short bursts** with 0.2–0.5 s sleeps, chained with `&&` or `set -e` so a failed locate stops later input.
3. **Verify** with state, then a fresh `grim` capture if layout changed.

How to write these scripts correctly (key chords, the Mod key, holds, typing, closing things, the pointer scale): [references/scripting.md](references/scripting.md). Runnable patterns: [examples/](examples/) (`calc-smoke.sh`, `writer-format.sh`, shared `lib.sh`).

## Pointer scale

`mousemove --absolute -x X -y Y` lands at about (2X, 2Y) on this machine (re-verified 2026-10-12 on eDP-1, 1920×1200, scale 1). `ui.py move/clickat/click` correct for it; override with `YDOTOOL_SCALE` if a pointer capture (`grim -c`) shows another factor. Don't change acceleration or monitor layout to fix it.

## Screenshots and recordings

`grim /tmp/x.png` (whole desktop), `grim -g 'X,Y WxH'` (region, note the `x`), `grim -c` (draw cursor), `grim -s 0.5` (half size, cheaper to view). View with the image tool. Recordings and frame extraction: [references/testing.md](references/testing.md).

## Desktop

Bindings, chords, app desktop rules, Quickshell IPC and config sources: [references/desktop.md](references/desktop.md). Read it before switching desktops, moving windows or opening shell menus.

## Obsidian plugin tests

Use a scratch vault or disposable fixture files. Set state with `obsidian eval` (for example `app.workspace.getLeaf('tab').openFile(...)`), act with real input, assert with eval. Store results in `window.__m` and read them with a second eval; wrap in `try/catch`. Element screen positions come from DOM rects, see [references/atspi.md](references/atspi.md#obsidian-and-electron). `obsidian dev:screenshot path=<png>` captures Obsidian even off-screen (take it twice; the first can lag).
