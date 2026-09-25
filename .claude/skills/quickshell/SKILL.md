---
name: quickshell
description: How to change or extend the quickshell desktop shell in this dotfiles repo (de/.config/quickshell) — cards, pickers/menus, windows, the bar, singletons, IPC targets, feature flags — and how to verify the change actually loads. Use for any edit under de/.config/quickshell, for adding a keybind that opens a shell surface, or for debugging a qs/QML error here.
---

# Quickshell in this repo

The shell lives in `de/.config/quickshell/` (stowed to `~/.config/quickshell`, so
edits are live). `CLAUDE.md` → **Quickshell Desktop Widgets** and **Music player**
hold the *why* behind each component; read the section for the component you're
touching before changing it — most odd-looking code there is a fix for something.
This skill is the *how*.

## Hard constraints

These are properties of this box, not style preferences. Breaking one fails silently.

- **Software renderer** (`QT_QUICK_BACKEND=software` in `~/.local/sv/quickshell/run`).
  `ShaderEffect`, `layer.effect`, `MultiEffect`, `layer.enabled` blur/shadow draw
  **nothing**. Recolour icons with `QtQuick.Controls.impl`'s `ColorImage`; punch
  holes with `Canvas` (`destination-out`), as `Spotlight.qml` does. Every pixel is
  decoded and scaled on the CPU, so **every `Image` gets a `sourceSize`** capped to
  what it draws.
- **Flat and themed.** `radius: Theme.borderRadius` (0). Colours only from
  `Theme.*` — add a named token to `Theme.qml` rather than a literal. No drop
  shadows, no Material ripples, and no motion beyond what exists (the wallpaper
  crossfade, the Gauge fill).
- **Sizes through the scale.** `Config.s(n)` (or `root.s(n)` inside a `Widget` /
  `Picker`) — the laptop runs at 0.85. Raw pixel counts are wrong on one machine.
- **IPC functions are `toggle` / `hide` / `open` — never `show`.**
  `qs ipc call <t> show` is swallowed by the `qs ipc show` subcommand (exits 0,
  handler never runs). `open` is what the launcher's `>` menu calls.
- **Nothing runs while it is not needed.** Polls on a closed menu are
  `running: root.open`; picker content is built only while its box is visible
  (Picker's Loader does this); features are `LazyLoader`s so an off switch means
  never built. Don't fork a subprocess per tick for something `/proc`, `/sys` or a
  Quickshell service can answer.

## Code conventions

Every file follows these; qmllint enforces most of them.

- `pragma ComponentBehavior: Bound` on line 1 (line 2 after `pragma Singleton`).
- The root object is `id: root`.
- Delegates declare what they read and get an id; children go through that id:
  ```qml
  delegate: Rectangle {
      id: entry
      required property var modelData
      required property int index
      Txt { text: entry.modelData.name }
  }
  ```
  Once a delegate declares any `required` property, the implicit context names
  (`modelData`, `index`, ListModel roles) stop being injected — declare every one
  you use.
- Functions that return nothing are `: void`. **Leave parameters untyped** unless
  you've checked every caller: a QML annotation coerces the argument (`int`
  truncates a real, `string` turns `null` into `"null"`).
- A file in a subfolder needs `import ".."` for `Theme`/`Config`/`Txt`/`Poll` and
  the root singletons.
- Don't redeclare an `Item` property (`enabled`, `visible`, `baseline` …).
  `baseline` is FINAL and fails the **whole shell** load; the others silently
  shadow the built-in.
- JSON from a command comes through `Poll`'s `onJsonData` and is filtered in JS —
  no `jq` (it isn't a dependency any more).

## Where a new thing goes

| You're adding… | Base | Location |
|---|---|---|
| an ambient desktop card | `Widget` (+ `CardHeader`, `Gauge`, `Graph`) | `cards/` — then fit it into the card layout chain in `CLAUDE.md`, which moves the cards around it |
| a full-screen menu / picker | `Picker` + `PickerList` + `PickerRow` (or `PickerSearch` + `PickerResults` for type-to-filter) | root |
| a surface you sit in and resize | `Scope` + `IpcHandler` + `FloatingWindow` (see `monitors/Monitors.qml`) | own folder if it has helpers |
| shared state read by several files | a `Singleton` | **root** — Quickshell auto-registers singletons only there |
| a transient per-output indicator | `Variants` over `Quickshell.screens`, window sized to the content (see `Osd.qml`) | root |

Folders exist only for **closed clusters** — nothing outside references the
contents. A folder with no singletons needs no `qmldir` (implicit import). A folder
with a singleton needs a `qmldir`, and then **every** file in it must be listed:
an explicit module replaces the directory listing, and a missing line fails with
an error naming the *type*, not the qmldir. New folders get an `import "x"` in
`shell.qml`.

Templates for each row are in [templates.md](templates.md).

## Wiring a new feature

1. `Config.qml` → one `{ key, group, label }` entry in `features` (the settings
   menu is generated from it).
2. `shell.qml` → `LazyLoader { active: Config.on("<key>"); Thing {} }`.
3. A surface with IPC → an `IpcHandler` with `toggle`/`hide`/`open`, and a row in
   `launcher/Commands.qml`'s `catalogue` (its key hint is read out of reach's
   config automatically).
4. A keybind → `de/.config/reach/config.zon`, spawning exactly
   `qs ipc call <target> toggle`. A `FloatingWindow` shares the `org.quickshell`
   app_id, so any reach window rule for it must match on **title** too.
5. `CLAUDE.md` → the component list, plus anything non-obvious you had to learn.

## Reuse before writing

| Need | Use |
|---|---|
| text / text input | `Txt`, `Field` (font + colour baked in) |
| a command on an interval | `Poll` — `onData` (raw) / `onJsonData` (parsed or null), `refresh()`, `running` |
| volume, mic, default devices | `Volume` singleton |
| CPU/RAM/disk/GPU/battery | `Sys` singleton |
| desktops, focused output, brightness, temperature | `Reach` singleton (reach's socket, write-only — you can't send it commands) |
| notifications | `NotificationService` (`live`, `history`, `paused` = DND) |
| which output / scale | `Config.screen(name)`, `Config.pinScreen`, `Config.onLaptop`, `Config.s()` |
| list navigation + keys | `Picker.navKey(e)`, `move()`, `selectable()`, `count` |
| hover that doesn't fight the keyboard | `PickerHover` — never raw `onEntered` for selection |

## Gotchas that cost time before

- **`.js` libraries (`.pragma library`) don't hot-reload.** New functions read as
  `TypeError … is not a function` with a clean load log. Restart the service.
- **QML hot reload goes stale** after enough edits. Before deciding a change
  didn't work, restart: `SVDIR=~/.local/sv sv restart quickshell`.
- **A hidden `FocusScope` keeps focus.** A modal built once and hidden steals every
  key afterwards; build it with a `Loader` so closing destroys it.
- **Z-order is declaration order.** A card-wide `MouseArea` goes *before* the
  content or it swallows the buttons' clicks.
- **An `onCompleted` runs after the first binding read.** State the first frame
  depends on (e.g. `Config.overrides`) is an initial binding, not `onCompleted`.
- **A `Socket` connect that fails emits no state change** (it never entered the
  connected state), so a retry hung off `onConnectionStateChanged` fires once and
  never again. Drive it from a Timer with `running: !sock.connected` (`Reach.qml`).
- **Restarting quickshell closes the music window** (it's opened by reach's
  autostart, not by qs). Reopen it with `qs ipc call music open` after testing.

## Verifying a change

Run all of these; a clean `Configuration Loaded` alone proves nothing, because
pickers and windows are only built when opened.

```sh
cd ~/dotfiles/de/.config/quickshell

# 1. Static: qmllint filtered to the categories that are real here, plus the
#    Bound pragma and no IpcHandler show(). Prints "lint: N files clean".
~/dotfiles/tests/lint.sh

# 2. Load: restart, wait for IPC, open what you touched, read the log.
SVDIR=~/.local/sv sv restart quickshell
until qs ipc show >/dev/null 2>&1; do sleep 0.3; done
qs ipc call <target> toggle; sleep 1; qs ipc call <target> hide
qs log 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -vE 'INFO|portal.Settings'

# 3. Everything (lint again + the FileSearch/MusicController units):
~/dotfiles/tests/run.sh
```

The only expected log noise is the `org.freedesktop.portal.Settings` warning.
**Never call `lock lock`** to test — it locks the user's session. `qs ipc show`
lists every target.

Unit tests can only load files that import nothing but `QtQuick` — Quickshell's
plugin is linked into the `qs` binary, so `qmltestrunner` can't import it. Keep
logic you want tested in a QtQuick-only file (as `MusicController.qml` and
`FileSearch.js` are); `tests/run.sh` stages copies so a sibling `qmldir` doesn't
drag Quickshell in.
