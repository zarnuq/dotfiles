# reach config (`de/.config/reach/`)

Loaded when working in this directory. The root `CLAUDE.md` carries a short summary and the traps that matter from anywhere; this is the full detail. reach's source lives in `~/reach` (outside this repo; installed by `emerge reach`).

**Config:** `de/.config/reach/config.zon` — ZON (Zig Object Notation), **live-reloadable**: `Super+Shift+r` (`.reload`) or `kill -HUP $(pidof reach)` re-reads it, and the monitor layout comes with it — but only when the `.monitors` block actually **changed by value** (`reload.zig` diffs the two generations while both arenas are alive; re-applying an unchanged mode set is a visible flicker for nothing). When it has, `outputconfig.reapply()` reuses the last output-manager serial rather than waiting for a `done` that editing a file never triggers; a stale serial gets `cancelled`, which re-arms the normal path. Each load parses into its own arena against a snapshot of the compiled-in defaults, so reload is idempotent and a field dropped from config.zon returns to its default instead of keeping the old value. A reload is only *requested* from the signal/keybind handler and applied at the top of the next manage cycle. A parse error leaves the running config alone, so a typo is survivable — but note the unknown-key trap below still applies at **startup**, where the fallback is the compiled-in defaults (no binds). `env` and `autostart` are deliberately **startup-only** — the variables went into a process tree that already exists and the programs already ran, so a reload logs that it skipped them rather than duplicating them. Every field optional → falls back to compiled-in default (`config.zig`). Lookup order (first wins): `$XDG_CONFIG_HOME/reach/config.zon`, `~/.config/reach/config.zon`, `/etc/reach/config.zon`. Colors `0xRRGGBB` (border) / `0xRRGGBBAA` (bar). Read the file for exact behavior/keybinds/rules; notes below cover the non-obvious wiring.

**Selected output follows the pointer, in two halves.** river's `river_seat_v1.pointer_enter` names a WINDOW, so entering an output with nothing under the cursor never moved the selection: the bar highlighted the monitor whose window you last touched, and — the half that actually bites — the desktop keys acted on it. reach now also reads `pointer_position` (`src/seat.zig`), maps it through `query.outputAt()` and sets `current_output`. That event is sent **only inside a manage sequence** (motion alone must never start one), which is as often as any WM can know: the selection is therefore right at the moment it is USED, since a keybind is a manage sequence, but it does not move while you merely slide the mouse across a bare desktop. The live half is quickshell's: the wallpaper is the one surface covering a whole output, so its hover sets `Reach.hoveredOutput`, and `Reach.selected(name)` layers that over the socket's `focused` for the bar highlight. Above a window the wallpaper gets nothing — which is exactly the case `pointer_enter` already sees, so the two cover the screen between them. Only the output selection moves; `ctx.focused` is left alone, since crossing a screen edge onto empty desktop should not take the keyboard away from the window you were typing in.

**Behavior:** `sloppy_focus=true` (focus follows mouse), `nmaster=1`, `mfact=0.6`, gaps 0/0, borders 5px — `border_active` `0xcba6f7` (mauve), `border_inactive` `0x45475a` (surface1). Unfocused windows *do* carry a border now (it used to be focus-only, blue, 2px); the accent moved to mauve to match the rest of the theme.

**Shake to find** — `.cursor.shake` no longer grows the cursor; it runs `.command` (`qs ipc call spotlight flash`, quickshell's `Spotlight.qml`) once the gesture has been held `.delay` ms (450). reach detects the gesture from raw evdev deltas and can do nothing more with it: `river_seat_v1.pointer_position` only arrives inside a manage sequence (`src/shake.zig` header), so reach never learns where the pointer *is*, and as river's WM client rather than the compositor it has no surface to draw on. Growing worked only because a cursor size is a bare number for `set_xcursor_theme`. `.speed` is gone from the schema and `.command` is new, so **binary and config.zon must land together** — an unknown key fails the whole ZON parse and drops reach to compiled-in defaults (no binds).

**Gamma (dimming + night light)** — reach owns the screen's gamma ramps itself (`src/gamma.zig`, `protocol/wlr-gamma-control-unstable-v1.xml`), which **replaced `wl-gammarelay-rs`** and the two scripts that drove it. Two knobs, deliberately asymmetric: **brightness** is runtime state with a keybind and no config field (`.{ .brightness = ±5 }`, applied to every output in-process — no script, no daemon, no bus round trip, floored at 10% so a key can never black the screen out), and **temperature** is a config field with no action (`.gamma = .{ .temperature = 4000 }`; a reload *is* the night-light switch). Non-obvious bits: (1) **why the WM.** `zwlr_gamma_control_v1` is held, not set — the client keeps the object alive for as long as the adjustment lasts, the compositor restores the original ramp the instant it dies, and only one client per output may hold one. So the owner has to be the longest-lived process in the session. (2) That exclusivity means **wl-gammarelay-rs (or wlsunset/gammastep) must not be running**, or reach's controls come back `failed` and dimming silently does nothing — the log says so. (3) Ramps are normalised against 6500 K, so "neutral" is an exact identity table rather than a faint cast; the colour math is the Kim et al. Planckian fit redshift and wlsunset use, **then gamma-encoded** — the fit gives multipliers in linear light, a ramp holds encoded values, and attenuating an encoded `v` by a linear `f` needs `f^(1/2.2)·v`. Applied raw, 4000 K sends `1.000/0.692/0.380` instead of `1.000/0.846/0.644` (redshift's table), which reads as a screen both far redder *and* much darker than asked for, since green carries most of the perceived luminance. A test pins 4000 K against that table. (4) The table goes over a **memfd**, not `wl_shm` — `set_gamma` takes a bare fd — and reach closes its copy right after, which is correct rather than a double close because libwayland dups the fd while marshalling. (5) It is re-asserted on a `dimensions` change, since a mode set can land after the ramp was written. (6) **It cannot be tested in a nested session**: the wayland and headless backends have no hardware LUT, so every output there answers `failed`.

**Monitor layout** — array order defines numbering for `focusmon`/`tagmon` and the `.monitor` index in window rules:

| Idx | Name  | Res       | Pos       | Transform  | Notes                       |
|-----|-------|-----------|-----------|------------|-----------------------------|
| 0   | DP-3  | 3440x1440 | 0,0       | rotate_180 | Primary ultrawide           |
| 1   | DP-2  | 3440x1440 | 0,1440    | normal     | Secondary UW (`mainScreen`) |
| 2   | DP-1  | 1920x1080 | 3440,1440 | rotate_270 | Vertical, 165 Hz            |

This table is the **desktop** preset. Layouts now live in **`de/.config/reach/monitors.zon`**,
not as commented-out blocks in `config.zon` — see **Monitor layouts** below. The laptop
group is:

| Idx | Name  | Res       | Pos      | Transform  | Notes                        |
|-----|-------|-----------|----------|------------|------------------------------|
| 0   | DP-5  | 1920x1080 | 0,0      | normal     | On a stand above the laptop  |
| 1   | eDP-1 | 1920x1200 | 0,1080   | normal     | Laptop panel                 |
| 2   | DP-3  | 1920x1080 | 1920,0   | rotate_270 | Portrait, right of the stack |

A head that isn't connected is simply ignored. That used to mean the two groups could
not both be live (`DP-3` and `DP-1` appear in both, and a duplicate name is two entries
for one head); presets removed that constraint, since only one is applied at a time.

**Monitor layouts (`monitors.zon`)** — the layout is its own file beside `config.zon`,
found by the same XDG lookup. **reach's entire share of this is: open that path, parse
`.{ .monitors = ... }`, assign it.** No presets, no `active` field, no name matching —
deliberately, because everything cleverer belongs in whatever writes the files.

Keeping several layouts is therefore the filesystem's job: `de/.config/reach/monitors/`
holds one file per arrangement (`laptop.zon` = the panel alone, `docked.zon` =
DP-5/eDP-1/DP-3, `desktop.zon` = the three-head block above) and **`monitors.zon` is a
symlink** to the one in use. Switching is re-pointing the link plus a reload; reach
opens a path, the kernel follows the link, and `reload.zig` already re-applied the
monitor table only when it changed by value, so nothing was needed there either. The
non-obvious bits: (1) **the link is gitignored, the layouts are committed** — which one
is current is per-machine state, the same reason `features.json` lives outside the repo.
(2) A **dangling link reads as no file at all**, so a deleted layout degrades to "no
monitors.zon" rather than to an error. (3) `monitors.zon` **wins over a `.monitors`
block in config.zon**, so both can coexist during a migration — and an extra *file* is
invisible to an older binary, unlike an unknown *key*, which fails the whole parse.
(4) A present-but-**malformed** monitors.zon fails the entire load, config.zon included,
rather than being skipped as absent: skipping it would reset the layout to whatever
config.zon says — usually nothing — so a typo would scatter the screens instead of
costing a log line. (5) This needs the reach binary that knows `monitors.zon` at all; an
older one just ignores the file.

**GUI** — `Super+R` `m` (`qs ipc call monitors toggle`), quickshell's `monitors/` (see
`de/.config/quickshell/CLAUDE.md`). It owns everything the WM doesn't: which layouts exist, which is live, switching
the link, and writing the files. It regenerates a layout file from its parsed contents,
so each file's header comment survives a save and anything else hand-written below it
does not.

**A rotated head's `.w`/`.h` are its MODE; the transform swaps them.** `DP-3` is
`1920x1080` in the config and occupies `1080x1920` on the desktop — which is why
river's auto-placement once left an 840px dead gap beside it, having sized it as
1920 wide. This is also why the `.monitor` index in a window rule means a different
output on each machine. A head that isn't connected is simply ignored,
but leaving both groups live would give the same name two entries.

Every entry needs an explicit `.x`/`.y`. The defaults are `-1,-1`, which reach reads
as "don't send `set_position`" — river then auto-places the head wherever it likes
(it put HDMI-A-1 side-by-side with eDP-1, not above it). The laptop's external sits
past x=5000 so it never collides with the desktop's DP block.

**Env vars (set by reach `.env` block):** `XDG_CURRENT_DESKTOP=river`, `XDG_SESSION_TYPE=wayland`, `QT_QPA_PLATFORM=wayland`, `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus`, `PROTON_ENABLE_WAYLAND=1`, plus an explicit **`PATH`** and **`XDG_DATA_DIRS`** that put `~/.nix-profile` first — greetd doesn't reliably hand the nix profile down (it differs between the desktop and the laptop), so without them a bind spawning a nix-installed binary silently does nothing. Note this `XDG_DATA_DIRS` is nix-**first**, while `home.nix`'s `home.sessionVariables` copy is nix-last; reach's is the one a session actually gets. Does **not** set `QT_QPA_PLATFORMTHEME`/`QT_STYLE_OVERRIDE` (old dwl setupenv did) — re-export if Qt apps stop picking up qt6ct/Kvantum.

**Autostart** (`de/.config/reach/autostart.sh`) is minimal — most daemons moved to runit user services. It: pins `DBUS_SESSION_BUS_ADDRESS` to `$XDG_RUNTIME_DIR/bus`, starts `runsvdir $HOME/.local/sv` if not running and waits for the bus socket, retries `qs ipc call music toggle` until quickshell's IPC answers, and `dconf load`s `~/.config/dconf/interface.dconf` into GNOME settings.

**Window rules** (match `app_id`/`title`; `^foo`=starts-with, `foo`=contains; **`desktop` = 1-based number**, not the old `tags` `1<<n` bitmask; `switchto` replaced `switchtotag`; `monitor`=array index): quickshell's music window (`org.quickshell` + title `Music`)→desktop 1 on mon 2 (DP-1), zen→desktop 3 + switchto, signal→desktop 4, `^steam`→desktop 5, `^float`→floating centered 50%×50%.

**Status bar** — **gone from reach entirely**. The bar is quickshell's (`Bar.qml`); `bar.zig`, the in-process someblocks engine (`status.zig`), `render/` (fcft/pixman glyph rasterization) and the whole `.bar` config block were deleted, ~1.4k lines. `.bar = .{ ... }` in config.zon is now an **unknown key** — and an unknown key fails the whole ZON parse, dropping reach to compiled-in defaults (no binds, no monitor layout). Two consequences worth remembering: the old `enabled = false` line had to come *out of* config.zon **before** installing the new binary (a removal is accepted by both), and with an *old* binary a reload now turns the bar back **on**, since a dropped field reverts to its compiled-in default (which was `true`). `Output.usableArea()` no longer subtracts anything — a panel's exclusive zone reaches the layout through river. SIGHUP reload survived the deletion in `src/signals.zig`; it used to ride the status engine's SIGRTMIN signalfd, so `kill -35`-style block refreshes are gone with it. reach no longer links fcft or pixman (borders are single-pixel buffers), and the overlay ebuild's RDEPEND dropped both.

**State socket** (`src/ipc.zig`, new) — reach publishes what its bar used to draw, since nothing about desktops/focus/titles is reachable any other way: river is non-monolithic, reach *is* the WM, and there is no compositor-side workspace protocol for a panel to bind. A SOCK_STREAM unix socket at `$XDG_RUNTIME_DIR/reach.sock` emits one JSON line per **change**, each a *complete* snapshot (`{"desktops":9,"brightness":100,"temperature":4000,"outputs":[{name,desktop,focused,fullscreen,occupied[],title,appId}]}`; the two gamma fields are what let the panel drop its `gdbus monitor`) — whole snapshots, not deltas, so a reconnecting client needs no resync and can't apply anything out of order. Published from the render cycle, the same beat that redrew the internal bar; composing is skipped entirely when no client is connected. **Deliberately write-only**: client fds are read only to notice a disconnect. A `view <n>` command for clickable desktop cells would have to name the output too — `action.view` acts on `query.selectedOutput()`, so a click on an unfocused monitor's bar would switch the focused one — and moving the selection is a focus-semantics decision, not one a status socket should make.

**Keybinds:** `Super`=Mod. A `.binds` block **replaces the entire** default action/spawn/chord keymap **except** the auto-generated per-tag digit binds (`Super`/`+Ctrl`/`+Shift` + `1`–`9` = view/toggle/move, never listed in config). See `config.zon` for the full map. Notable: launchers (`Super+Tab` kitty, `Super+BackSpace` floating kitty, `Super+Space` quickshell launcher (`qs ipc call launcher toggle`, replaced rofi), `Super+Shift+Escape` shell settings (`qs ipc call settings toggle`), `Super+t` zen, `Super+w` music player (`qs ipc call music toggle`), `Super+V` clipboard history (`qs ipc call clipboard toggle`, replaced clipfzf), `Super+X` killfzf, `Super+Z` svfzf, `Super+Shift+Z` ssvfzf), two-key chords: `Super+r` = apps (`d` signal, `b` firefox, `m` display configurator, `s` steam, `a` audio mixer, `n` network menu — which is also where the VPNs are, `t` Bluetooth menu, `u` removable drives), `Super+s` = screenshots (`s` quick, `d` annotate the clipboard image, `0`–`3` a whole output each), `Alt+[` cycle EQ sink, `Alt+Up/Down` volume, `Alt+Left/Right` mic, `Alt+End` mic mute, `Super+Alt+Left/Right` brightness (in-process `.brightness` action, no script), night light via `.gamma.temperature` + reload rather than a key, `Super+P` lock (`qs ipc call lock lock`; the lock screen also carries poweroff/reboot/logout), `Super+b` random wallpaper (`qs ipc call wallpaper random`), `Super+Shift+b` wallpaper picker (`qs ipc call wallpaperpicker toggle`).
