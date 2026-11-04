# Miles's River / Reach / Quickshell setup

## Sources of truth

- `/home/miles/.config/reach/config.zon` → `/home/miles/dotfiles/de/.config/reach/config.zon`: custom keymap, sloppy focus, app rules, startup environment.
- `/home/miles/.config/reach/monitors.zon`: selected display preset symlink. At creation: laptop layout, eDP-1 at 1920×1200, position (0,0). Inspect current outputs instead of assuming it stays undocked.
- `/home/miles/.config/quickshell/`: shell components and IPC handlers.
- `/home/miles/Projects/reach/README.md` and `src/binding.zig`: generated desktop bindings, chords, state protocol. Custom `binds` replace default action bindings; the config overrides README default shortcut tables.

Re-read relevant config sections if shortcuts fail or config changes. This is non-monolithic River with Reach; `riverctl` is absent. Reach status is at `$XDG_RUNTIME_DIR/reach.sock` (this session: `/run/user/1000/reach.sock`), falling back to `/tmp/reach.sock`. Run `python3 <skill-directory>/scripts/inspect_desktop.py --state` to connect briefly, read one complete newline-delimited JSON snapshot, and close. Fields include desktop count and output `name`, `desktop`, `focused`, `occupied`, `title`, `appId`. This is status only: sending text commands does not control Reach. On 2026-10-12 the `title` field stayed on one window while focus moved by hover, click and Super+J/K, so use it for desktops and occupancy, not for focus (see [scripting.md](scripting.md#changing-focus)). It reports focused titles per output, not every window. Do not hold extra subscriptions open; Reach supports four clients.

Sloppy focus is enabled. Entering a window selects its output/window. Pointer movement over bare desktop may not update the socket until a manage cycle, but the next shortcut can act on the output under the pointer. Use a screenshot and pointer placement together with state. Switch desktops on the intended output, then focus the intended application before typing.

Reach uses exclusive desktops: one desktop per output, one desktop per window. No classic River tag bitmask, toggle-view, or all-tags shortcut. Verify desktop switches; empty desktop behavior follows Reach's implementation.

## Actual bindings

`Super` = left Win/logo key, evdev 125. Digits 1–9 use evdev 2–10.

| Shortcut | Action |
| --- | --- |
| Super+1..9 | View desktop 1..9 |
| Super+Shift+1..9 | Send focused window to desktop |
| Super+J / K | Focus next / previous stack window |
| Super+comma / period | Focus previous / next monitor |
| Super+Shift+comma / period | Send window to previous / next monitor |
| Super+Enter | Promote focused window to master (zoom) |
| Super+F | Toggle floating |
| Super+Shift+F | Toggle fullscreen |
| Super+arrows | Move floating window by 40 pixels |
| Super+Shift+arrows | Resize floating window by 40 pixels |
| Super+H / L | Decrease / increase master area by 0.05 |
| Super+M / N | Decrease / increase master count |
| Super+Tab | Launch kitty |
| Super+Backspace | Launch floating kitty (`--class float`) |
| Super+Space | Toggle launcher |
| Super+V | Toggle clipboard picker |
| Super+X | Toggle processes menu |
| Super+W | Toggle music window |
| Super+T | Launch zen-browser |
| Super+Shift+Escape | Toggle settings |
| Super+Z / Super+Shift+Z | Floating kitty running `svfzf` / `ssvfzf` (runit service pickers) |
| Super+B / Super+Shift+B | Random wallpaper / wallpaper picker |
| Super+Alt+Left / Right | Brightness −5 / +5 % (gamma, all outputs) |
| Alt+Up / Down | Volume up / down (global: apps never see Alt+Up/Down) |
| Alt+Left / Right | Mic down / up (global) |
| Alt+End / Alt+[ | Mic mute / flip audio output |
| XF86AudioPlay / Prev / Next | Media control |
| Super+Shift+R | Reload Reach config |
| Super+Shift+Q | Kill focused client |
| Super+P | Lock screen |
| Super+Shift+P | Quit Reach and River session |

Use lock, kill, quit, and reload only when the user's task calls for them. Super+Enter does not launch a terminal here.

Layout (config.zon): master-stack, `nmaster` 1, `mfact` 0.6 (runtime-adjustable), no gaps, 5 px borders (`#cba6f7` focused, `#45475a` unfocused), floating windows default to 0.6 × 0.65 of the output, centred. `binds` replaces the default keymap, so the table above is complete apart from the generated Super+1..9 / Super+Shift+1..9.

App rules: Obsidian → desktop 2; Zen → desktop 3 with automatic switch; Signal → desktop 4; Steam → desktop 5. Quickshell Music → desktop 1 on configured monitor 2 when available. Class/app_id starting `float` → floating. Read state after launches because rules can change focus/placement.

## Chords and shell IPC

Chords are sequential: press/release the leader including Super, allow the submap to activate, then press/release an unmodified sub-key. Do not hold Super through the second key.

- Super+R then D → Signal; B → Firefox; A → audio; N → network; O → notifications; T → Bluetooth; U → drives; M → monitors; S → Steam.
- Super+S then S → region capture; D → annotate clipboard image; 1/2/3 → capture display in left-to-right order.

Example: open monitors with Super+R, release both, wait about 0.1 seconds, tap M:

```sh
ydotool key 125:1 19:1 19:0 125:0
sleep 0.1
ydotool key 50:1 50:0
```

Prefer direct Quickshell IPC for a requested shell action when accessible. `/usr/bin/qs ipc show` lists running targets. Inspect the relevant QML/live IPC list before assuming `open`/`close` exists.

```sh
qs ipc call launcher toggle
qs ipc call clipboard toggle
qs ipc call settings toggle
qs ipc call network toggle
qs ipc call monitors toggle
qs ipc call music toggle
```

`toggle` can close an already-open menu: observe first. `qs ipc call <target> show` collides with the CLI's `ipc show` and may return success without invoking the handler. IPC access denial is a session/sandbox issue, not evidence the shell is down; use authorized ydotool bindings if its daemon is reachable. Verify visible results rather than treating successful calls as proof.

Use grim to a temporary PNG for automation screenshots. Quickshell `capture` methods are user-facing actions that may replace the clipboard or open an interactive selector. Query current geometry with `wlr-randr` when accessible; connector names are more reliable than indices. Do not apply monitor presets, reload config, or restart the session to discover geometry.
