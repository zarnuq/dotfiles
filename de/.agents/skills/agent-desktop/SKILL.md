---
name: agent-desktop
description: Test graphical apps and Obsidian plugins on Miles's isolated headless river/Reach desktop while he uses his normal desktop. Use for GUI testing, screenshots and automated mouse/keyboard interactions; use the host ydotool skill only when the task explicitly needs his existing desktop.
---

# Isolated graphical testing

Use `~/.local/bin/agent-desk`. It controls a real second river/Reach instance,
with its own display, clipboard, D-Bus and accessibility bus. **Files are the
real ones** (same home, same `~/notes`): edit only scratch copies. No extra TTY
or privilege elevation is needed after setup.

Reach config, copied at `start` (restart the desktop for host config edits):

- Default (agent): the user's real **binds** (so the compositor swallows the
  same chords it does on the host), but click-to-focus, no window rules (apps
  open on the current desktop), no gaps or borders (windows fill 1920×1200 at
  0,0, so window = screen coordinates).
- `agent-desk stop && agent-desk start --real-config`: also the real sloppy
  focus, rules (Obsidian → desktop 2), gaps and borders, for testing Reach or a
  fully faithful run. `status --json` reports `real_config`. `start` reuses a
  running desktop, so stop first to switch.
- Never carried: `.env` (host bus), autostart, gamma, shake-to-find, brightness
  and reload binds (backlight; a reload would read the host's Reach config).
  Quickshell does not run, so `qs ipc` binds do nothing.
- Apps get the host `XDG_CONFIG_HOME` / `XDG_CACHE_HOME` (only Reach uses a
  private one), so GTK/dconf dark mode, fonts and app settings match the host.

For practical recipes, including manual viewing, doc-works editing, build
refreshes, keyboard/pointer examples and troubleshooting, read
[references/examples.md](references/examples.md) as needed.

## Check the session

`agent-desk status --json` reports health, input ownership, output dimensions,
complete window inventory, and the running Reach path/PID/start time/SHA-256.
`agent-desk start` is idempotent. If a session is unhealthy, inspect the logs in
its reported runtime directory; do not send input to the host as a fallback.

A paused/manual session belongs to the user. Do not resume it automatically;
wait for the user to hand control back. Closing the viewer does not resume the
agent. Input bursts are serialized. Held keys/buttons have a five-second lease;
use `agent-desk release` on cancellation.

Commands are serialized one at a time, but a multi-step sequence is not atomic.
**Claim the desktop** for a sequence; other agents' input is then refused
(the user's view/pause/resume/stop never are):

```sh
eval "$(agent-desk claim my-task 120)"   # exports AGENT_DESK_CLAIM; lapses after 120 s idle
...                                      # every agent-desk call carries the token
agent-desk unclaim
```

A refusal names the holder and its remaining idle time: wait, don't steal it.

## Act and verify

```sh
agent-desk windows --json
agent-desk focus 3
agent-desk wait-window obsidian            # prints the id; fails after --timeout (20 s)
agent-desk shot --cursor /tmp/agent.png
agent-desk shot --window 3 /tmp/win.png    # cropped to one window
agent-desk move 800 400
agent-desk click left
agent-desk type -- 'Literal text, including café and λ'
agent-desk key Ctrl+s
agent-desk scroll down 3
agent-desk drag 800 400 1000 600
agent-desk clip set -- '## Markdown'       # private clipboard; --type text/html for rich text
agent-desk clip get                        # also: clip types, clip clear
agent-desk record start /tmp/run.mp4       # video of the output; record stop finishes it
agent-desk opened                          # links apps tried to open (logged, never opened)
agent-desk wait-idle                       # until the screen stops changing; use instead of sleeps
agent-desk find-text 'Save changes'        # OCR: prints 'X Y' to click (--all, --window ID)
agent-desk compare base.png new.png --diff d.png   # exit 1 above --tolerance (0.002) of changed pixels
```

`find-text` is for text with no DOM or accessibility tree (canvas grids,
native dialogs). It returns matches in reading order, ignores accents, and
retries across a caret blink. Check a click target from it on a screenshot:
the same text can appear twice (a sheet's formula bar and cell).

The clipboard is the private desktop's own, never bridged to the host's (the
user's copies may hold secrets). Links and `xdg-open` calls from apps started
by `run`/`obsidian` are logged to `opened.log` instead of opening a browser on
the user's real profile; assert on `agent-desk opened`.

Read a fresh screenshot before choosing coordinates. Coordinates are pixels in
this desktop's output, normally 1920×1200 at scale 1: do not apply the host
skill's 2× mouse correction. Window IDs belong to one Reach process; rediscover
IDs after restarting. `focus ID` also selects a hidden window's desktop.
`geometry ID X Y WIDTH HEIGHT` floats and places a window, in output-local
coordinates. Client minimum sizes may differ from requested dimensions.

`key` accepts XKB names and chords, including `Ctrl`, `Alt`, `Shift`, `Super`,
`Return`, `Escape`, `space`, `plus` and `F1`. Write Shift chords the natural way
(`Ctrl+Shift+z`, `Super+Shift+q`, `Shift+Tab`): `key` sends the shifted keysym,
because WayVNC otherwise drops every modifier to reach a lowercase keysym. `key --down Shift` / `key --up Shift`
can bracket a short pointer operation. `type` uses compositor-scoped wtype and
supports leading spaces and Unicode; it refuses text while input is held.

`agent-desk a11y apps` and `agent-desk a11y tree --depth 4` inspect the private
accessibility bus only. Some Electron builds expose no AT-SPI tree. Window
bounds are relative to the client window; use `screen_bounds` only when present
and verified. Screenshots remain the authority for screen coordinates. Do not
run the host `ui.py` click commands: those call host ydotool.

## Obsidian / doc-works

doc-works has a ready suite: `npm run build && npm run test:gui [-- filter]` in
`~/Projects/doc-works` (`scripts/gui-test.py`). It copies the bundle, reloads
the plugin if Obsidian is already open, edits fresh fixture copies in
`~/notes/doc-works-test/gui-<time>/` through the GUI, checks the saved XML,
deletes the folder on success and prints an evidence folder (screenshots +
`results.json`). Each test also fails on uncaught errors or `console.error`
lines logged while it ran. `test_visual_baselines` compares the untouched
fixtures' page / slide / grid with approved images in
`~/.local/state/agent-desk/baselines/doc-works/` (written on first run;
`UPDATE_BASELINES=1 npm run test:gui -- visual` after a change you accept;
a theme change counts). Extend it with a `test_*` function for new features.
Run Python helpers that import `agent-desk` with `/usr/bin/python3`; Nix's
python3 cannot load the system libxkbcommon.

```sh
agent-desk obsidian --plugin-dir ~/Projects/doc-works
agent-desk obsidian-cli eval 'code=JSON.stringify({vault:app.vault.adapter.basePath,file:app.workspace.getActiveFile()?.path,plugins:Object.keys(app.plugins.plugins)})'
```

This opens the **real `~/notes`** in a separate Electron profile whose
per-device config folder is `~/notes/.obsidian-agent` (Syncthing-ignored). Each
launch (when the private app isn't running) copies the real `.obsidian` there,
minus workspace files: same theme, snippets, plugins, plugin settings, hotkeys
and core-plugin choices. The built plugin goes into `.obsidian-agent/plugins/`,
never the user's installed copy; hashes are in
`~/.local/state/agent-desk/plugin-build.json`. The host app's `.obsidian` is
never written. Before trusting a run, check `app.vault.configDir` is
`.obsidian-agent`; if it is `.obsidian`, stop the desktop at once (it would
rewrite the user's workspace) and report it. Every launch re-checks the
override from a scratch vault first (~4 s) and refuses to open `~/notes` if it
cannot be confirmed.

The user's real settings apply: the quick switcher core plugin is **off**, so
open files by clicking them in the file explorer (reveal via eval first).
Put test files only in `~/notes/doc-works-test/` and delete them afterwards.
Copying a bundle into a running app does not reload it: close the private
Obsidian or disable/enable the plugin via eval.

Use `obsidian-cli` through this wrapper: it connects directly to the private
instance's Unix socket and checks its process group. The default host Obsidian
CLI must not be used for these assertions. Always check the vault and active
file in the same eval before scripted edits. Use eval for setup/assertions;
exercise the interaction under test through the actual GUI, then verify saved
files or application state and capture the result.

`agent-desk run -- COMMAND …` launches other GUI apps in the same private
environment. Give single-instance apps a separate profile when necessary.
Don't launch GUI apps from a shell in a private kitty: the user's zshrc resets
`XDG_RUNTIME_DIR` to the host's, so they would open on the host desktop. Use
`run`, or `kitty --config NONE … zsh -f`.

## Manual access and lifecycle

The user opens these from the **Agent desktop** app entry (launcher, or `>`
mode): `agent-desk.desktop` opens the bar panel (`qs ipc call agentdesk open`)
with Start / View / Take control / Pause-Resume / Stop.

- `agent-desk view`: read-only live viewer on the user's normal desktop.
- `agent-desk view --control`: pause the agent and give the viewer input.
- `agent-desk resume`: revoke manual input and return control explicitly.
- `agent-desk stop`: close only this desktop and its owned apps.

After the normal shell reloads, its AI badge opens an app/status panel with
the same controls.
Do not automatically open a viewer during unattended testing: that intentionally
opens a window on the user's desktop. Do not use ydotool, broad pkill/killall,
unqualified Quickshell IPC, or host activation-environment updates to operate
this desktop. Reach's optional control socket has no shell-execution command.
