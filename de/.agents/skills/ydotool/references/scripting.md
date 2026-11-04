# Scripting ydotool correctly

Verified with ydotool 1.0.4 through `/run/ydotoold/socket` on 2026-10-12. Runnable versions of every pattern here: [../examples/lib.sh](../examples/lib.sh).

## Shell shape

- **Wrap commands in functions, not strings.** zsh does not word-split `$cmd args`: `U="python3 ui.py"; $U find x` fails with `no such file or directory`. Use `ui() { ...; }`.
- **Stop on the first failure.** Use `set -eu` in scripts and `&&` between locate and act steps in one-liners. In an earlier session a failed locate step was followed by typing that still ran and went to whatever had focus.
- **Wrap AT-SPI calls in `timeout 30`.** A hung accessibility call otherwise blocks the shell.
- **Absolute path and socket every time:** `YDOTOOL_SOCKET=/run/ydotoold/socket /home/miles/.nix-profile/bin/ydotool ...`. Without the socket variable, 1.0.4 tries `$XDG_RUNTIME_DIR/.ydotool_socket`, which does not exist here.
- `ydotool click` prints a line like `c0 110` on stdout. This is normal output, not an error. Redirect it to `/dev/null`.
- Subcommand `--help` needs a reachable daemon. Top-level `--help` does not.

## Keys

`key` takes Linux evdev codes as `CODE:1` (press) and `CODE:0` (release). It does not accept X11 codes, keysyms or `ctrl+c`. Press modifiers first and release them last in reverse order, all in one invocation:

```sh
ydotool key 29:1 46:1 46:0 29:0                 # Ctrl+C
ydotool key 125:1 42:1 33:1 33:0 42:0 125:0     # Super+Shift+F
```

| Key | Code | Key | Code |
| --- | --- | --- | --- |
| Left Ctrl | 29 | Right Ctrl | 97 |
| Left Shift | 42 | Right Shift | 54 |
| Left Alt | 56 | AltGr | 100 |
| Super / Mod (Reach) | 125 | Right Super | 126 |
| Escape | 1 | Tab | 15 |
| Enter | 28 | Backspace | 14 |
| Space | 57 | Delete | 111 |
| Left / Right | 105 / 106 | Up / Down | 103 / 108 |
| Home / End | 102 / 107 | PageUp / PageDown | 104 / 109 |
| F1..F10 | 59..68 | F11 / F12 | 87 / 88 |
| Digits 1..9, 0 | 2..10, 11 | comma / period | 51 / 52 |
| Q W E R T Y U I O P | 16..25 | A S D F G H J K L | 30..38 |
| Z X C V B N M | 44..50 | minus / equal | 12 / 13 |

For other keys, look up `KEY_*` in `/usr/include/linux/input-event-codes.h`.

## Mod key navigation

Mod is Super (Left Win, evdev 125). Reach handles these keys before the application sees them. The full table is in [desktop.md](desktop.md). These are the keys you need most:

```sh
ydotool key 125:1 3:1 3:0 125:0      # Super+2: view desktop 2 (Obsidian)
ydotool key 125:1 36:1 36:0 125:0    # Super+J: focus next window in the stack
ydotool key 125:1 37:1 37:0 125:0    # Super+K: focus previous window
ydotool key 125:1 28:1 28:0 125:0    # Super+Enter: swap focused window into master
ydotool key 125:1 52:1 52:0 125:0    # Super+period: focus next monitor
```

- **Chords** (Super+R, Super+S): tap the leader with Super, release everything, wait about 0.1 s, then tap the sub-key with no modifier. Do not hold Super through the sub-key.
- After a Mod action, re-read focus (`inspect_desktop.py --state`, a screenshot border, or `ui.py focus`) before typing.
- `--state` reports `"mod": true` while Reach sees Super held. If it stays true after your sequence, a release was lost. Send `125:0` once.
- **Alt+arrows are global here.** Alt+Up/Down change volume and Alt+Left/Right change mic gain. Apps never receive them, so Alt+Down (open dropdown) does not work in any app. Open a dropdown by clicking its arrow, or type into an editable combo box. Alt+End mutes the mic and Alt+[ flips the audio output.
- Super+Alt+Left/Right change screen brightness. Avoid these in tests.

## Changing focus

All four methods were verified on 2026-10-12 with Writer, Calc and kitty tiled on desktop 1:

| Goal | Input | Notes |
| --- | --- | --- |
| Window visible on this desktop | Move the pointer over it: `ui.py move X Y` | Sloppy focus selects the window on pointer entry. The pointer must cross into the window; a move that stays inside the same window changes nothing. |
| The same, with certainty | `ui.py clickat X Y` on a harmless spot | Use a margin, a title bar or a gray canvas area. Never click a control. |
| Next / previous window in the stack | Super+J / Super+K | Cycles master, then the stack, in order (Writer, Calc, kitty, Writer). Count presses, or check focus after each one. |
| Window on another desktop | Super+1..9 | Obsidian is on 2, Zen on 3, Signal on 4, Steam on 5. Then hover or click inside it. Switch back when done. |
| Other monitor | Super+comma / Super+period | Only when docked. |
| Raise a window to master | Super+Enter | Changes the layout, so the `UI_ORIGIN` values for both windows change. |

**Check focus with a source that tracks it.** The Reach `--state` title did not change through any of the switches above. Do not use it to confirm focus. Use one of these instead:

- `ui.py apps`. The focused accessible window ends in `| active`. No `active` line means focus is in a non-accessible window (kitty, Obsidian, Zen).
- The border pixel. The focused window's border is `cba6f7`. Read one pixel on the target's edge: `grim -g "X,Y 1x1" -t ppm - | tail -c 3 | od -An -tx1`.
- A screenshot. Look for the purple border.

Moving the pointer for any reason, including a click elsewhere, can move focus under sloppy focus. Re-check focus after a pointer move and before typing. When you finish, leave focus where Miles had it: hover his terminal or press Super+J/K back to it.

## Closing things

| Target | Input | Notes |
| --- | --- | --- |
| Menu, popup, dropdown, tooltip | Escape (`1`) | Escape once per open level. Open submenus need one press each. |
| Dialog | Escape, or Tab to Cancel + Enter | Escape cancels without applying. Click OK by name with `ui.py click '^OK$' --role button`. |
| Quickshell overlay (launcher, settings, menus) | Escape or the same toggle again | Overlays grab the keyboard. Close them before you type into an app. |
| Document in LibreOffice | Ctrl+W (`29 17`) | Prompts if there are unsaved changes. Answer with Tab or click **Don't Save** by name. |
| Obsidian tab | Ctrl+W | Closes the active tab, not the window. |
| Whole LibreOffice | Ctrl+Q (`29 16`) | Quits gracefully and prompts for each unsaved document. |
| Application window | Super+Shift+Q (`125 42 16`) | Reach `killclient`. Unsaved work is lost or a prompt appears. Use only for windows you opened, or when the task says so. |
| Whole session | Super+Shift+P | Never. This quits River. |

Close only what the test opened. Leave Miles's other windows and documents alone.

## Holds and drags

Pair every press with a release and guarantee it with `trap` (shell) or `try/finally` (Python). Put at least two intermediate moves between button down and up, because web apps act on `pointermove`:

```sh
trap 'ydotool click 0x80' EXIT
ydotool click 0x40; sleep 0.15                       # left down
ydotool mousemove --absolute -x 436 -y 175; sleep 0.15
ydotool mousemove --absolute -x 436 -y 180; sleep 0.2
ydotool click 0x80; trap - EXIT                     # left up
```

The click value is a bitmask: button 0/1/2 (left/right/middle), plus `0x40` for down and `0x80` for up. `0xC0` is a full left click and `0xC1` is a full right click. Scroll with `mousemove --wheel -y -1` in small steps, and check the direction.

If you are interrupted, release only the keys and buttons this sequence pressed. Miles may be holding keys physically.

## Pointer

Absolute moves use relative events, and pointer acceleration doubles them. To land on screen pixel (px, py), send `-x px/2 -y py/2`. `ui.py move`/`clickat` do this, and `YDOTOOL_SCALE` overrides the factor. Check the result with `grim -c` (draws the cursor). Sloppy focus means that moving the pointer over a window can focus it. Keep the pointer inside the target window.

## Typing

- `ydotool type --escape=0 -- 'literal'` types US-ASCII only. Use `type --file <path>` for multiline text. Every newline becomes an Enter press, which can submit forms or run terminal commands.
- For Unicode text, run `wl-copy`, then press Ctrl+V. This replaces the clipboard.
- **Applications rewrite typed text.** LibreOffice AutoCorrect capitalised `bold part` to `Bold part` after a full stop. Read the text back (`ui.py text`, `obsidian eval`) before you assert on it.
- Never put untrusted text inside shell code. Pass it as an argument or as a file.

## Timing

Sleep 0.2 to 0.5 s between steps, and about 1.5 s after a step that opens a window or dialog. Wait for state instead of sleeping longer: poll `ui.py find` or `cell` until the expected value appears.
