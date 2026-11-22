# Quickshell (`de/.config/quickshell/`)

The how-to (constraints, conventions, templates, verifying a change) is the **`quickshell` skill**. This file holds the rules that apply to every edit here. Each component's *why* is in `notes/`: **before editing a component, read its note** (index below). The music player has its own `music/CLAUDE.md`.

## Always true here

- **Features:** `shell.qml` is one `LazyLoader { active: Config.on("<key>") }` per feature. A feature that's off is never built, and toggling it at runtime builds or tears it down live. `active:` is synchronous on purpose: an all-async shell never loads. `Config.qml` holds only the catalogue (`{key, group, label}` in menu order). On/off is per-machine state in `~/.local/state/quickshell/features.json`, outside the repo, storing only the OFF switches; a missing file means everything is on. Edit it through the settings menu (`Super+Shift+Escape`), not by hand. A new feature is one catalogue entry plus one `shell.qml` line.
- **Service:** `~/.local/sv/quickshell/run` waits for the dbus and wayland sockets, then `exec qs`. It sets `QT_QPA_PLATFORM=wayland`, `QT_WAYLAND_DISABLE_WINDOWDECORATION=1` and `QT_QUICK_BACKEND=software`. Scale lives in `Config.qml` (`DP-2` present means 1.0, else 0.85).
- **Software rendering:** about 15 windows would each get a GL render thread otherwise (589 MB/135 threads against 260 MB/22). So GPU-only QML draws nothing: no `ShaderEffect`, `layer.effect` or `MultiEffect`. Recolour icons with `QtQuick.Controls.impl`'s `ColorImage`.
- **Layout on disk:** the root holds the standalone surfaces and shared singletons. A subfolder exists only where nothing outside references its contents: `bar/`, `cards/`, `music/`, `launcher/`, `wallpaper/`, `monitors/`. Each is a directory import in `shell.qml`, and every file inside has `import ".."`. Only `music/`, `launcher/` and `wallpaper/` have a `qmldir`, and only for their singletons. Don't add one elsewhere: it forces listing every file. **A file added to `music/` needs a `qmldir` line**, or it silently doesn't exist.
- **Root stays root:** `Theme`/`Config`/`Txt`/`Poll`/`Gauge`, the `Picker*` chrome, and the state singletons `Reach`/`Sys`/`Power`/`Volume`/`NotificationService`. `Reach.qml` is shared by the bar and the gamma readers (`Brightness`, `Osd`), so it belongs to no folder.
- **QML conventions:** every file has `pragma ComponentBehavior: Bound` (after `pragma Singleton`) and root `id: root`. Delegates declare `required property var modelData` / `required property int index`, get their own `id`, and children read `thatId.modelData`. Functions returning nothing are annotated `: void`. Parameters stay **untyped**: an annotation coerces (`int` truncates, `string` turns `null` into `"null"`). `tests/lint.sh` checks these.
- **`.js` library edits need a real restart** (`SVDIR=~/.local/sv sv restart quickshell`): hot reload doesn't re-read a `.pragma library`.
- **IPC:** `qs ipc call <target> show` collides with the `qs ipc show` subcommand. Expose `open`/`hide`/`toggle`, never `show()`, and type every `IpcHandler` argument.
- **Deps:** nvidia-smi, curl, python3 (stdlib only). **No `jq`**: filter JSON in JS or Python.

## Shared pieces (reuse before writing)

`Config.s(n)`/`Config.screen(name)`, `Theme` (palette plus `alpha()`, `currentWash()`, `rowSelectBg/Fg`), `Widget` (card chrome), `Txt`/`Field`, `CardHeader`, `HeaderBtn`, `Graph`, `Gauge`, `Poll` (`onJsonData` gives parsed JSON or null), `Picker` (overlay, IPC, list navigation over `count`), `PickerRow`/`PickerList`/`PickerSearch`/`PickerResults`/`PickerFooter`/`PickerHover`, `NetworkData.js`, `Volume`, `Power`, `Sys` (CpuGraph only), `NotificationService`. Details and reasons: `notes/shared-pieces.md`.

## Component notes (`notes/`)

`components.md` (every feature, its keybind, what it replaced) · `shared-pieces.md` · `scripts.md` (`monitors.py`, `calendar.sh`, `ai-usage.py` …) · `cards.md` (card layout) · `monitors.md` (display configurator)

`Bar` (with `Reach`) · `Spotlight` · `Session` (lock screen and power menu, `doas -n` bare names) · `Audio` · `Network` (Wi-Fi, VPN mirror of `~/VPNs`, import guards, never `con mod`) · `FileIndex` (launcher `/` mode) · `Commands` (launcher `>` mode) · `Keybinds` · `ClipboardPicker` · `Clipboard` · `Osd` · `WallpaperPicker` · `Wallpaper` · `NotificationPopups` · `Battery` · `Brightness` (with `Sys`, `CpuGraph`) · `Mpd` · `Calendar` · `Settings` (with `Config`) · `Picker` · `Launcher`, each at `notes/<Name>.md`.

## Agent desktop

`AgentDesktopState.qml` reads the private supervisor's status.json. `AgentDesktop.qml` is an opt-in panel (feature `agentDesktop`) behind the bar's AI badge and the `agentdesk open/hide/toggle` IPC target. Controls call `~/.local/bin/agent-desk`. View is read-only, and Take control pauses the agent; it opens no viewer until asked. The private desktop is a second river/Reach, not another TTY. Logout and Reach-reload callers use `session-signal` to target the current session's Reach socket. Runtime details: `de/.local/share/agent-desk/README.md`.
