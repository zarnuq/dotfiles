# Agent desktop

A real headless river/Reach desktop for GUI tests while the normal desktop stays
usable. The installed `agent-desk` command is linked to the dotfiles source.

```sh
agent-desk start
agent-desk obsidian --plugin-dir ~/Projects/doc-works
agent-desk windows
agent-desk shot /tmp/agent.png
agent-desk view
```

`view` is read-only. `view --control` pauses agent commands and gives the viewer
mouse/keyboard input. `resume` revokes viewer input; closing the viewer alone
leaves the agent paused. `stop` closes the private desktop and its owned apps.
No viewer is opened automatically by startup or unattended tests.

Click the normal bar's **AI** badge for app titles, status, View, Take control,
Pause/Resume and Stop. It is a normal Quickshell feature toggle, **Agent desktop**.
Its IPC target is `agentdesk` (`open`, `hide`, `toggle`). A stale Quickshell hot
reload can require a service restart; restarting closes its Music/Displays
windows. Until it reloads, the old shell also retains its old logout/reload
actions. The widget/panel were exercised in a separate desktop.

## Reach config

`start` copies the real `~/.config/reach/*.zon` (except `monitors.zon`) into the
private config dir, dropping brightness binds (Reach opens the host backlight even
headless), and adds `zz-agent-desk.zon`, merged last, which empties `.env` (it
names the host bus) and `autostart`, and turns off gamma and shake-to-find. By
default it also sets agent-friendly values: click-to-focus, no window rules, no
gaps or borders. `start --real-config` keeps the real focus, rules, gaps and
borders instead. Quickshell isn't started; `qs ipc` binds do nothing there.

Reach runs with a private `XDG_CONFIG_HOME` (that is how it finds this config).
Apps must not inherit it: GTK reads dark mode from `$XDG_CONFIG_HOME/dconf/user`,
fontconfig and most apps read their settings there too. `run`/`obsidian` spawn
with the host config/cache dirs, and the override's `.env` hands the same to
Reach's own children (binds); the reload bind is dropped, since a reload would
then read the host Reach config.

`agent-desk.desktop` (linked into `~/.local/share/applications`) opens the
Quickshell panel; its actions run View, Take control, Resume and Stop.

`key` sends the shifted keysym for Shift chords (`Shift+q` → `Q`, `Shift+Tab` →
`ISO_Left_Tab`, US layout): WayVNC's `send_key_with_level` otherwise rewrites the
modifiers to the keysym's own level, so `Super+Shift+q` arrived as a bare `q`.

## Claims, links, recording

A claim (`claim NAME [IDLE_S]`, default 300 s idle) makes input, `clip`,
`record`, `run`/`obsidian` and window commands refuse callers without its
token (`AGENT_DESK_CLAIM`, sent with every request). `status` shows the holder.
View/pause/resume/stop stay the user's and are never gated.

Apps started by `run`/`obsidian` get `~/.local/state/agent-desk/bin` first in
PATH, holding an `xdg-open` that appends to `opened.log` (Electron's link
opening goes through it). It lives in state, not the runtime dir, because
`/run/user` is mounted noexec; `start` refuses if apps would not resolve it.
An unshimmed `xdg-open` once started a second Zen on the real profile inside
the private desktop ("Close Zen" dialog).

## Runtime and control

Default runtime is `$XDG_RUNTIME_DIR/agent-desk`, with private Wayland, Reach,
D-Bus, AT-SPI, VNC and command endpoints below it. Directories are mode 0700.
`AGENT_DESK_RUNTIME` selects another instance and is exported to its children.
WayVNC listens only on Unix sockets; no TCP listener or clipboard bridge is
configured. Private D-Bus activation is updated inside the new bus, never the
host bus.

`status --json` includes running/paused/manual status, all managed windows,
owned process summaries and the loaded Reach PID/starttime/binary SHA-256.
`status.json` is also published for the widget without subprocess polling.
Logs (fresh on every `start`; they used to append across sessions) are `supervisor.log`, `river.log`, `input.log`, `view.log`, `viewer.log`
and `app.log` in that runtime directory. `error.json` records startup failures.

Commands:

| Command | Purpose |
| --- | --- |
| `start [--real-config] [--reach PATH] [--wayvnc PATH] [--width N --height N]` | Idempotent startup; default 1920×1200, scale 1, agent Reach defaults |
| `run -- COMMAND …` | Start an app using the private session environment |
| `obsidian [--plugin-dir PATH]` | Real `~/notes`, private profile + `.obsidian-agent` config, plugin copy |
| `obsidian-cli COMMAND …` | Direct checked private Obsidian Unix CLI connection |
| `windows [--json]` / `focus ID` | Discover and select managed windows |
| `desktop N` | Select desktop 1–9 |
| `geometry ID X Y W H` | Float and place a window using output-local geometry |
| `close ID` | Ask the named app window to close |
| `shot [--cursor] [--window ID] PATH` | Capture the virtual output (or one visible window) using grim |
| `wait-window TEXT [--timeout S]` | Print the id of a window whose appId/title contains TEXT |
| `clip set TEXT` / `get` / `types` / `clear` `[--type MIME]` | The private clipboard (wl-copy/wl-paste); never bridged to the host |
| `record start PATH` / `record stop` | wf-recorder video of the output |
| `claim NAME [IDLE_S]` / `unclaim` | Exclusive input lease; prints `export AGENT_DESK_CLAIM=…` |
| `opened` | Links/`xdg-open` calls apps made (logged by a shim, never opened) |
| `obsidian-reveal PATH` | Reveal a vault file in the private Obsidian's explorer; print its row's X Y |
| `kill PID` | End an app `run`/`obsidian` launched (its process group); `close` only asks |
| `wait-idle [--timeout S] [--quiet S] [--threshold F] [--window ID]` | Until frames stop changing (a caret blink is under the threshold) |
| `compare A B [--tolerance F] [--level N] [--diff OUT]` | Pixel diff (PIL); exit 1 above tolerance; diff = changes in red |
| `find-text TEXT [--window ID] [--all]` | OCR (tesseract, `app-text/tesseract`): screen `X Y` of a phrase |
| `move X Y` / `click [left\|middle\|right]` | Absolute pointer and buttons |
| `scroll up\|down\|left\|right [COUNT]` | Scroll through virtual pointer events |
| `drag X1 Y1 X2 Y2` | Left-button drag |
| `type -- TEXT` | Literal multiline/Unicode keyboard input through wtype |
| `key CHORD` / `key --down KEY` / `key --up KEY` | XKB key names/chords |
| `release` | Release held agent keys/buttons |
| `a11y apps` / `a11y tree --depth N` | Read the private accessibility tree |
| `view [--control] [--no-open]` | Attach viewer or prepare its socket only |
| `pause` / `resume` / `stop` | Ownership and lifecycle |

Held agent input expires after five seconds. Commands are serialized and fail
when paused or when an endpoint is missing; there is no host-input fallback.
Window IDs are valid only within their Reach process. A WM acknowledgement is
not proof that an application rendered/saved; verify its state and saved files.

## Obsidian

`obsidian` opens the real `~/notes` in a private Electron profile
(`~/.local/state/agent-desk/obsidian`) whose per-device config folder override
(localStorage `<vaultId>-config`) is `~/notes/.obsidian-agent`. Files are the real
ones; the host app's `.obsidian` (workspace, installed plugin builds) is never
written. Before each launch with no private Obsidian running, the real `.obsidian`
is copied over `.obsidian-agent` without `workspace*.json` or sync conflicts
(symlinked plugins are copied as files); the given plugin build is then installed
there and enabled. `plugin-build.json` records source, version, vault and hashes.
`/.obsidian-agent` is in `~/notes/.stignore`.

The override must exist before `~/notes` first opens in the profile, or Obsidian
uses and rewrites the real `.obsidian`. The first launch therefore opens the
scratch vault `~/.local/state/agent-desk/vault`, sets the override and plugin
trust (`enable-plugin-<vaultId>`), quits cleanly (a killed renderer loses
unflushed localStorage), and reads both back in a second, fresh process. Every
later launch first re-reads them from the scratch vault (~4 s) and only then
opens `~/notes`; a mismatch rewrites and re-verifies them, or refuses.

```sh
agent-desk obsidian-cli eval 'code=JSON.stringify({vault:app.vault.adapter.basePath,configDir:app.vault.configDir,file:app.workspace.getActiveFile()?.path})'
```

The CLI socket must belong to a live Obsidian process group started by this
supervisor. Electron rewrites its environment/title memory, so `/proc/environ`
is not used to identify the Obsidian instance. AT-SPI works for the tested GTK
app; this Electron build did not register an AT-SPI app even when renderer
accessibility was enabled. Use the checked CLI/DOM for assertions and actual
mouse/keyboard input for the interaction under test.

This is not a security sandbox. The host remains the same user and shares
files, CPU and GPU. Use separate profiles for other single-instance apps.

## Builds and the river cursor compatibility issue

Reach changes are in `~/Projects/reach`, with a portable copy of the patch here
as `reach-agent.patch`. Agent protocol 1 is opt-in through `REACH_AGENT_SOCKET`;
the normal WM is not restarted or given a command endpoint. The old panel socket
remains read-only. Same-UID checks, bounded packets and a small command grammar
apply to the new endpoint; it has no shell-execution command.

```sh
cd ~/Projects/reach
zig build --system zig-pkg -Doptimize=ReleaseSafe
zig build test --system zig-pkg --summary all
```

The wrapper uses the installed `/usr/bin/reach` (`gui-wm/reach-9999`), which
carries the agent socket. To try a local build, pass it explicitly with
`agent-desk start --reach PATH`; the live ebuild builds upstream source, not the
local working tree.

river 0.4.8 + wlroots 0.20.2 panics on WayVNC 0.10.1's separate cursor-capture
session. The trace ends at `get_capture_session` and river's `Server.zig`
assumes that capture sources are outputs or managed windows, not cursors.
The small private compatibility build skips separate cursor capture only when
`WAYVNC_NO_CURSOR_CAPTURE` is set; `-r` embeds the cursor in the captured output.
The installed `/usr/bin/river` and `/usr/bin/wayvnc` are unchanged.

```sh
python3 ~/.local/share/agent-desk/build-wayvnc.py
```

The helper uses the cached Portage WayVNC 0.10.1 archive, builds against installed
libraries without downloading anything or invoking Git, and records source and
binary hashes plus the license beside the executable. The default executable
is `~/.cache/agent-desk/wayvnc-compat/wayvnc`. A different source version requires
reviewing the compatibility patch. Required packages installed in @world are
`gui-apps/wayvnc`, `net-misc/tigervnc` and `gui-apps/wtype`.

Literal typing reserves wtype's first generated keycode with an unheld Escape
release; this was needed to preserve leading spaces in the tested Electron
editor. Chords and persistent pointer input use the private VNC input client.
No kernel uinput device is used.

The `session-signal` helper resolves Reach through the current environment's
state socket, validates peer UID and process identity, and uses pidfds for a
specific Reach/river signal. Logout and Reach reload callers use this instead
of broad process-name signals. `session-signal river TERM --check` reports its
target without signalling it.

## Verification

```sh
/usr/bin/python3 ~/dotfiles/tests/agent-desktop/smoke.py
```

This starts a real GTK app only in the existing private desktop, exercises
Unicode text, chords, pointer/drag/scroll, geometry, hidden desktops, screenshots,
manual handoff, read-only viewing and private accessibility, then closes its
window. It saves screenshots and a JSON result under `/tmp/agent-desk-smoke-*`.
It refuses to take over an initially paused session. Actual TigerVNC rendering
was additionally tested in a second disposable desktop, without opening a host
viewer window. doc-works opened, edited and saved its copied `.docx` fixture,
including literal spaces/Unicode, with the source fixture unchanged.
