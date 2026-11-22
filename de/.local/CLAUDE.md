# Custom scripts and runit user services

Loaded when working in this directory. Moved out of the root `CLAUDE.md`, which keeps only an index.

## Custom Scripts (`de/.local/bin/`)

- **flip.sh** — `set <sink>` only: makes it the default, sets the USB2.0 card to `iec958-stereo` first so the optical chain's `target.object` resolves, and migrates playing streams (only those with an `application.name` — never the filter chains' own inputs). Called by the quickshell audio menu and by `Volume.flip()` (`Alt+[` → `qs ipc call volume flip`), which owns the EQ-sink cycle now.
- **wallpaper-thumbs** — pre-renders 400x225 JPEG thumbnails of `~/Pictures/bgs` into `$XDG_CACHE_HOME/wallpaper-thumbs` for the quickshell picker; idempotent (only missing/stale files are rendered), fans out via `xargs` re-entering itself as a worker. `--list` emits `category<TAB>source<TAB>thumb` — the picker's only source of thumb paths.
- **svfzf / ssvfzf** — two runit service managers (floating kitty + fzf; glyphs ●/○/·). **Split in two** because per-call `doas` prompts broke inside the fzf action loop (stdin is the pick pipeline). `svfzf` = **user** services in `~/.local/sv` (no elevation; enable/disable = `rm`/`touch` a `down` file; `Super+Z`). `ssvfzf` = **system** services in `/etc/sv` (re-execs under `doas` **once** up front so root persists; enable/disable = add/remove `/service` symlink; no default keybind).
- **rebuild-kernel.sh** — Gentoo kernel rebuild ("lazygentoo", Secure Boot + UKI). Optionally updates `gentoo-sources` (`-e`), seeds + `olddefconfig`s `.config`, builds modules, rebuilds out-of-tree modules (`emerge @module-rebuild` — nvidia-drivers etc., else nvidia breaks every boot), `kernel-install add` (initramfs+UKI via `/etc/kernel/install.d` hooks), signs with ukify, prunes old UKIs, rewrites efibootmgr entry. Self-elevates via `doas`. `-y` skips prompt.

## Services (runit)

Two scopes, managed by `svfzf` (user, `Super+Z`) / `ssvfzf` (system, `doas`) or `sv` directly.

**User** (`~/.local/sv`, supervised by per-user `runsvdir` from reach autostart; disable = drop a `down` file): `dbus` (persistent user D-Bus **session** bus — whole stack inherits it), `pipewire` (**group service**: pipewire + wireplumber + pipewire-pulse), `mpd` (**group service**: mpd + mpd-mpris), `quickshell` (widgets + wallpaper + lock + notifications + **clipboard/cliphist watchers**), `syncthing`. Manage via `svfzf` or `SVDIR=~/.local/sv sv <cmd> <name>`. **Group services** run several related daemons from one `run` script (`wait -n` → kill the group → runsv respawns all together), so a crash of any one restarts the set as a unit. (Clipboard capture used to be a standalone `cliphist` group service — now owned by quickshell's `Clipboard.qml`.)

**System** (`/etc/sv` → `/service`, **outside this repo**, not stowed): enable/disable via the `/service` symlink. Inspect on-box; typically greetd/tuigreet, ufw, bluetooth, dbus, udisks2.

**Related notes that don't auto-load from here:** editing `bin/theme-set` means reading `de/.config/theme/CLAUDE.md` first (templates, consumers, matugen mapping). Editing `bin/flip.sh` means reading `de/.config/pipewire/CLAUDE.md` (the EQ sinks it cycles).
