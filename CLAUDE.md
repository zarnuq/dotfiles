# CLAUDE.md

Guidance for Claude Code when working in this repo.

> Per-app keybinding/setting tables that simply mirror a config file have been trimmed to keep this file small. When you need exact keys/values, read the config at the path noted in each section. What's kept here is context **not** derivable from the files themselves (platform quirks, migration debt, cross-component wiring).

## Overview

Personal dotfiles for a **Gentoo Linux** system. Wayland stack centered on **reach** (a custom **Zig** Wayland compositor; dwl-like — tags, master/stack tiling, regex window rules, an **in-process** someblocks-style status bar). GNU Stow manages all symlinks from `de/` → `$HOME`. Terminal is **kitty**. Theme is **Catppuccin Mocha (Mauve accent)** everywhere. UI aesthetic: **flat/sharp** — `border-radius: 0` explicitly everywhere.

System package manager is **Portage** (`emerge`). `sudo` is symlinked to **`doas`** on this box. `xbps`/`pacman`/`paru`/AUR do **not** apply. Nix + home-manager runs **alongside** Portage for a curated package set (security tools, GUI apps, Python libs). Clean nix with `nix-collect-garbage -d`.

> **Migration note:** previously Void Linux. Some configs still carry stale Void-era bits — see [Stale leftovers](#stale-voiddwl-leftovers).

## Repository Structure

```
de/                  # Stowed to $HOME
├── .config/         # App configs (incl. reach/, dconf/)
├── .local/bin/      # Custom scripts
├── .local/sv/       # Per-user runit service definitions
├── .local/share/    # Shared data (icons, rofi themes)
└── .zen/            # Zen browser chrome/userChrome.css
archive/             # Archived old configs
screenshots/         # README screenshots
```

> The old `de/.local/src/` (dwl/dwlb/someblocks source) is **gone** — reach replaced the dwl stack and builds outside this repo.

## Installation & Setup

Old `install*.sh` bootstrap scripts were **removed**. Setup: `git clone` → `cd dotfiles` → `stow de` → `home-manager switch`. `stow -D de` removes symlinks. reach is configured purely by `de/.config/reach/config.zon` (no build step here). User runit services are picked up by the `runsvdir ~/.local/sv` reach autostart launches.

## Nix / home-manager

Runs alongside Portage for packages not easily/freshly available via emerge. `home-manager switch` applies. Configs:
- `home-manager/home.nix` — main (GUI apps, Python); imports `default.nix`. **Intentionally minimal** — no longer manages GTK theming/cursors/fonts/Qt (those are stowed directly + pushed via `dconf load`). Sets only one session var: `XDG_DATA_DIRS=/usr/local/share:/usr/share:$HOME/.nix-profile/share`.
- `home-manager/default.nix` — thin entrypoint importing `modules/cyber.nix`.
- `home-manager/modules/cyber.nix` — security/pentest toolkit (`home.packages`): nmap, burpsuite, sqlmap, ffuf, feroxbuster, metasploit, hashcat, hydra, aircrack-ng, wireshark, bettercap, binaryninja-free, netexec, impacket, responder, etc. (full categorized list lives in the file).
- `home-manager/security-box/` — large per-category `*.nix` catalog, **NOT imported** by anything — staging/reference only.
- `nixpkgs/config.nix` — `{ allowUnfree = true; }` (needed for burpsuite, wpscan, binaryninja-free).
- `home.nix` Python set includes `icalendar`, `recurring-ical-events`, `x-wr-timezone` which power the quickshell calendar widget; `pipx` has tests disabled via override (suite breaks on newer `packaging`).

> `hashcat` is installed via nix but the comment recommends the **system** `hashcat` for OpenCL/GPU driver compat.

> **nix GL vs system nvidia:** anything needing OpenGL/EGL/NVENC must come from **Portage**, not nix. The nvidia driver is Portage-managed (`/usr/lib64/libEGL_nvidia.so.*`), but nix binaries run under nix's `ld.so`, which never searches `/usr/lib64` — so the vendor ICD at `/usr/share/glvnd/egl_vendor.d/10_nvidia.json` resolves to nothing and EGL init dies (`eglGetDisplay failed` → *"Your GPU may not be supported"*). Pointing `LD_LIBRARY_PATH` at `/usr/lib64` doesn't fix it: it shadows nix libs with system ones and breaks the app earlier. Bridging the two properly is what `nixGL` exists for, and it works by shipping a *nix-built* driver matching the running kernel module — not by reusing the system one. **OBS lives in Portage for this reason** (`media-video/obs-studio`, USE `nvenc wayland screencast pulseaudio`); keep it out of `home.nix` or `~/.nix-profile/bin` will shadow `/usr/bin` on PATH.

## Catppuccin Mocha Palette

Base `#1e1e2e` (bg) · Surface0 `#313244` · Surface1 `#45475a` (borders) · Text `#cdd6f4` · Subtext0 `#a6adc8` · **Mauve `#cba6f7` (accent: focus/active)** · Blue `#89b4fa` (focused border) · Green `#a6e3a1` · Peach `#fab387` (warn) · Red `#f38ba8` · Teal `#94e2d5` · Yellow `#f9e2af` · Lavender `#b4befe`.

## reach Window Manager

**Config:** `de/.config/reach/config.zon` — ZON (Zig Object Notation), read **once at startup**. Every field optional → falls back to compiled-in default (`config.zig`). Lookup order (first wins): `$XDG_CONFIG_HOME/reach/config.zon`, `~/.config/reach/config.zon`, `/etc/reach/config.zon`. Colors `0xRRGGBB` (border) / `0xRRGGBBAA` (bar). Read the file for exact behavior/keybinds/rules; notes below cover the non-obvious wiring.

**Behavior:** `sloppy_focus=true` (focus follows mouse), `nmaster=1`, `mfact=0.55`, gaps 0/2, border only on focused window (`0x89b4fa` blue, 2px).

**Monitor layout** — array order defines numbering for `focusmon`/`tagmon` and the `.monitor` index in window rules:

| Idx | Name  | Res       | Pos          | Transform  | Notes             |
|-----|-------|-----------|--------------|------------|-------------------|
| 0   | DP-3  | 3440x1440 | 0,0          | rotate_180 | Primary ultrawide |
| 1   | DP-2  | 3440x1440 | 0,1440       | normal     | Secondary UW      |
| 2   | DP-1  | 1920x1080 | 3440,1440    | rotate_270 | Vertical, 165 Hz  |
| 3   | eDP-1 | 1920x1200 | —            | normal     | Laptop screen     |

**Env vars (set by reach `.env` block):** `XDG_CURRENT_DESKTOP=river`, `XDG_SESSION_TYPE=wayland`, `QT_QPA_PLATFORM=wayland`, `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus`. Does **not** set `QT_QPA_PLATFORMTHEME`/`QT_STYLE_OVERRIDE` (old dwl setupenv did) — re-export if Qt apps stop picking up qt6ct/Kvantum.

**Autostart** (`de/.config/reach/autostart.sh`) is minimal — most daemons moved to runit user services. It: pins `DBUS_SESSION_BUS_ADDRESS` to `$XDG_RUNTIME_DIR/bus`, starts `runsvdir $HOME/.local/sv` if not running and waits for the bus socket, runs `redshift.sh 4000` (2s delay), launches `kitty --class rmpc rmpc`, and `dconf load`s `~/.config/dconf/interface.dconf` into GNOME settings.

**Window rules** (match `app_id`/`title`; `^foo`=starts-with, `foo`=contains; `tags`=`1<<n` bitmask; `monitor`=array index): rmpc→mon 2 (DP-1), zen→tag 4 + switchtotag, mpv→tag 1 + switchtotag, `^steam`→tag 16, `^float`/pavucontrol→floating centered 50%×50%.

**Status bar** (baked-in, someblocks-style: `icon ++ first stdout line`, re-run per interval and/or on `SIGRTMIN+n`). Blocks: `ip` (30s), `audio` (60s, RTMIN+1), `volume` (1s, RTMIN+1), `mic` (1s, RTMIN+2), `date` (1s), `battery` (30s). Scripts in `de/.config/reach/blocks/`. Keybinds poke it with `kill -35 $(pidof reach)` (audio/volume) and `kill -36` (mic) for instant refresh.

**Keybinds:** `Super`=Mod. A `.binds` block **replaces the entire** default action/spawn/chord keymap **except** the auto-generated per-tag digit binds (`Super`/`+Ctrl`/`+Shift` + `1`–`9` = view/toggle/move, never listed in config). See `config.zon` for the full map. Notable: launchers (`Super+Tab` kitty, `Super+Space` quickshell launcher (`qs ipc call launcher toggle`, replaced rofi), `Super+V` clipfzf, `Super+X` killfzf, `Super+Z` svfzf), `Super+r`/`Super+s` two-key chords (apps / screenshots), `Alt+[` cycle EQ sink, `Super+Alt+Left/Right` brightness, `Super+Alt+Up` night-light toggle, `Super+P` lock (`qs ipc call lock lock`), `Super+b` random wallpaper (`qs ipc call wallpaper random`).

## Per-app configs (read the file for exact keys/values)

- **Shell (ZSH)** — `de/.config/zsh/.zshrc` + `.zshenv`. zplug (syntax-highlight, autosuggestions, fzf-tab, spaceship, vi-mode). `EDITOR=nvim`, all tool homes redirect to `XDG_DATA_HOME`. Aliases: `gs`/`gac`/`gp` (git), `y` (yazi+cd), `doomsync` (restart emacs service + doom sync). `xi`/`xr`/`xu`/`xq` are **stale Void xbps wrappers** (see leftovers).
- **kitty** — `de/.config/kitty/kitty.conf`. JetBrainsMono Nerd Font 12, 1M scrollback, decorations hidden, Catppuccin Mocha. Window classes used by reach binds: `float` (fzf pickers), `rmpc` (music).
- **tmux** — `de/.config/tmux/tmux.conf`. Prefix `Ctrl+F`, base index 1, mouse on, zsh. Plugins via tpm: catppuccin, sensible, resurrect, continuum.
- **Neovim** — `de/.config/nvim/`. lazy.nvim. Leader `Space`, tab=4 expandtab, system clipboard, nvim-tree (right, no netrw), telescope, treesitter, lspconfig+mason (lua_ls, pyright), nvim-cmp, catppuccin. Spell en_us for md/text.
- **Doom Emacs** — `de/.config/doom/`. catppuccin, org `~/org/`, both PRIMARY+clipboard sync `t`. Runs as runit **user service** (`~/.local/sv/emacs`); `Super+D` opens `emacsclient -c`; `doomsync` = kill → `sv stop emacs` → doom sync → `sv start emacs`.
- **rofi** — `de/.config/rofi/config.rasi`, rofi-**wayland**, theme `spotlight-dark.rasi`. **Superseded** by the quickshell `Launcher.qml` for the `Super+Space` drun launcher; config kept for standalone `rofi` invocations.
- **yazi** — `de/.config/yazi/`. Hidden shown, vim nav. Openers: nvim/xdg-open/swayimg/zathura/mpv. Plugins: git, piper, mount, chmod. `setbg` opener uses `swww img` — **stale**, system uses `qs ipc call wallpaper set <path>`.
- **btop** — `de/.config/btop/btop.conf`. mocha theme, GPU nvidia/amd/intel.
- **Zen browser** — `de/.zen/` (userChrome.css + user.js, custom CSS enabled). `de/.config/mimeapps.list`: default browser zen, Discord→legcord.

## Quickshell Desktop Widgets

**Config:** `de/.config/quickshell/` — QML components + `scripts/` (data providers). Entry point: `shell.qml` (`ShellRoot`), where each feature is one `LazyLoader { active: Config.<flag>; <Component>{} }` line — a feature toggled off is **never built** (zero RAM, no daemon). `Config.qml` (singleton) is the **switchboard**: one bool per feature (`wallpaper`, `notificationPopups`, `notificationHistory`, `lock`, `clipboard`, `clock`, `cpuGraph`, `netGraph`, `ports`, `vpn`, `mpd`, `weather`, `calendar`, `brightness`, `tray`) — edit **only** this file to enable/disable parts, then `sv restart quickshell`. `active:` is synchronous on purpose (an all-`activeAsync` shell would never load — async loading needs an existing window first). Written in QML/Qt Quick; no separate daemon/open split — `qs` runs in the foreground and runsv supervises it directly.

**Service:** `~/.local/sv/quickshell/run` — waits for dbus+wayland sockets, sets `QT_QPA_PLATFORM=wayland`, `exec qs`. Unlike eww, no monitor/scale detection in the shell script — that logic lives in Widget.qml (`DP-2` present → scale 1.0, else 0.85).

**Components (shell.qml, gated by Config flags):** `WallpaperView` (per-screen wallpaper, replaces awww), `NotificationPopups` (toasts, replaces mako popups), `Lock` (idle+lock, replaces swaylock+swayidle), `Clipboard` (cliphist text+image watchers, replaces the runit cliphist service), `Clock`, `CpuGraph`, `NetGraph`, `Ports`, `Vpn`, `Mpd`, `Weather`, `Notifications` (history panel + DND), `Calendar`, `Brightness`, `Tray`, `Launcher` (drun app launcher, replaces rofi).

**Notable wiring:**
- `Lock.qml` — `IdleMonitor` at 300s → lock; `IpcHandler` target `"lock"` for `Super+P` (`qs ipc call lock lock`); `WlSessionLock` (ext-session-lock protocol); PAM auth to unlock.
- `Wallpaper.qml` / `WallpaperView.qml` — singleton; `IpcHandler` target `"wallpaper"` → `random` or `set <path>`; `Super+b` = `qs ipc call wallpaper random`; picks from `~/Pictures/bgs`. **RAM-critical:** the `Image` layers use `cache: true` + a single shared `sourceSize` (`Wallpaper.decodeSize`, the global max output WxH) so **all outputs share ONE decoded buffer** via `QQuickPixmapCache` — do **not** set `cache: false` or per-output `sourceSize` (that's what made every monitor hold its own copy, ~114 MB). The two crossfade layers free their source once faded out, so steady state holds a single buffer. GPU textures are still per-window but live in VRAM (nvidia), not RSS.
- `Clipboard.qml` — `Scope` with two self-restarting `Process` watchers (`wl-paste --type text/image --watch cliphist store`); inherits qs's `WAYLAND_DISPLAY` (no socket-wait needed). Replaced the runit `cliphist` group service. Picker (`clipfzf`, `Super+V`) unchanged — still reads `cliphist list`.
- `NotificationPopups.qml` — uses `Quickshell.Services.Notifications` (FreeDesktop D-Bus server). `de/.local/share/dbus-1/services/fr.emersion.mako.service` is a stub (`Exec=/bin/true`) that shadows the system mako activation file — prevents D-Bus from relaunching mako when qs restarts and momentarily drops the `org.freedesktop.Notifications` bus name.
- `Brightness.qml` / `Sys.qml` / `CpuGraph.qml` — brightness via wl-gammarelay-rs; CPU/RAM/disk + nvidia-smi GPU; `/proc/net/dev` + `ip -j addr` for net.
- `Mpd.qml` — **fully native, no subprocess polling**: transport/metadata/art/progress via `Quickshell.Services.Mpris` (follows the active MPRIS player, prefers a playing one then MPD — so it also drives Zen etc.; needs the `mpd-mpris` bridge in the `mpd` group service to put MPD on the MPRIS bus), volume/mute via `Quickshell.Services.Pipewire` (`defaultAudioSink`/`defaultAudioSource` + a `PwObjectTracker` to keep `.audio.volume`/`.muted` live). Replaced the old `mpc`×4/s + `wpctl`×2/s polling.
- `Calendar.qml` — ICS calendar (reads `calendar.url` via `calendar.sh`).
- `Launcher.qml` — minimal drun app launcher (replaces `rofi -show drun`). Opens on the **focused monitor**: a full-screen overlay is mapped per output (`Variants` over `Quickshell.screens`), but the box is drawn only on the output whose overlay contains the pointer — under reach's `sloppy_focus` that IS the focused monitor. reach exposes **no IPC** for the focused output and grants keyboard focus to *every* layer surface, so pointer containment (a `hoverEnabled` MouseArea latching `activeScreen`) is what singles one out; `activeScreen` is blanked on open (150ms DP-2 fallback timer) to avoid flashing on the previously-focused monitor. Shared query/results/selection state lives on the `Scope` root. Type to filter `DesktopEntries.applications` by name; Up/Down or Ctrl+K/J to move, Enter = `entry.execute()`, Esc / click-outside closes. Triggered by `IpcHandler` target `"launcher"` (`toggle`/`show`/`hide`); `Super+space` = `qs ipc call launcher toggle`.

**Scripts** (`de/.config/quickshell/scripts/`): `calendar.sh` (Python; needs `icalendar`+`recurring_ical_events` from home-manager; caches to `/tmp/eww-calendar.ics`), `ports.sh` (ss+jq), `vpn-manager.sh` (OpenVPN; state in `/tmp/eww-openvpn.*`).

**Deps:** jq, wl-gammarelay-rs+gdbus, nvidia-smi, curl, python3+icalendar+recurring-ical-events. (Mpd.qml no longer shells out to `mpc`/`wpctl` — it uses native Mpris + Pipewire; it does rely on an MPD→MPRIS bridge being on the bus.)

## GTK / Qt Theming

Flat (`border-radius: 0` global, enforced in `gtk-3.0/gtk.css`). GTK3/GTK4 are **stowed directly** as plain files (no longer home-manager–generated) — edit repo files + re-stow. Theme `catppuccin-mocha-mauve-standard+default`, icons **Papirus-Dark**, font JetBrainsMono Nerd Font, cursor Bibata-Modern-Classic.

- `de/.config/dconf/interface.dconf` — `dconf load`ed into `/org/gnome/desktop/interface/` by reach autostart (GTK apps reading GNOME settings).
- `de/.config/xsettingsd/xsettingsd.conf` — XSETTINGS for non-GTK/Qt apps (Firefox, Signal, Electron); must be running for dark theme + cursor. `Gtk/ApplicationPreferDarkTheme 1` required for Firefox/Signal dark mode.
- Qt6 `de/.config/qt6ct/qt6ct.conf` (style Kvantum, catppuccin-mocha-mauve) + Kvantum `de/.config/Kvantum/kvantum.kvconfig`.

## Audio: PipeWire + WirePlumber

**Config:** `de/.config/pipewire/` + `de/.config/wireplumber/`. PipeWire/WirePlumber/pipewire-pulse run as runit user services.

- `pipewire.conf.d/custom.conf` — `default.clock.rate = 192000`, `allowed-rates = [192000]`, `link.max-buffers = 16`.
- `pipewire.conf.d/sink-eq.conf` — 16-band parametric EQ via builtin `filter-chain` (replaces EasyEffects). Two EQ sinks pinned via `target.object` to specific hardware: `effect_input.eq_fiio` → FiiO K11 USB DAC, `effect_input.eq_optical` → USB2.0 optical. All bands `bq_peaking`, Q=2.3521, APO(DR); coefficients mirror old `easyeffects/output/EQ.json`. **Keep both instances' coefficients in sync if regenerating.** Verify: `wpctl status | grep -E "effect_input\.eq_(fiio|optical)"`.
- `wireplumber.conf.d/softvol.conf` — `api.alsa.soft-mixer = true` for all USB cards (`alsa_card.usb-.*`); required for USB software volume.

**EQ switching:** apps connect to the default sink; `~/.local/bin/flip.sh` (`Alt+[`) cycles the default between the two `effect_input.eq_*` sinks and migrates playing streams. Raw `alsa_output.*` sinks excluded (pick those via wpctl/pavucontrol to bypass EQ).

## Custom Scripts (`de/.local/bin/`)

- **screenshot.sh** — `ss` (clipboard), `section` (→satty), `DP-1/2/3` (full monitor →satty). Output `~/Pictures/screenshot-*.png`.
- **flip.sh** — cycles default sink between the two EQ sinks + migrates streams; sets USB2.0 card to `iec958-stereo` first so the optical chain's `target.object` resolves. `Alt+[`.
- **redshift.sh** — night-light for ALL outputs via `wl-gammarelay-rs` (gdbus, session bus). No arg = toggle 4000K↔6500K; `<K>` = absolute. Replaces old `gammastep.sh`.
- **brightness.sh** — software brightness for ALL outputs (incl. DP/HDMI w/o `/sys/class/backlight`) via wl-gammarelay-rs gamma dimming (session bus, no root/i2c). `up`/`down`/`set <0-100>`/`get`; floor 10%. Drives the quickshell brightness widget; `Super+Alt+Left/Right`.
- **clipfzf** — `cliphist list | fzf | cliphist decode | wl-copy`. `Super+V`.
- **killfzf** — `ps --forest` → fzf; Enter=SIGTERM, Ctrl-K=SIGKILL, Tab=multi. `Super+X`.
- **svfzf / ssvfzf** — two runit service managers (floating kitty + fzf; glyphs ●/○/·). **Split in two** because per-call `doas` prompts broke inside the fzf action loop (stdin is the pick pipeline). `svfzf` = **user** services in `~/.local/sv` (no elevation; enable/disable = `rm`/`touch` a `down` file; `Super+Z`). `ssvfzf` = **system** services in `/etc/sv` (re-execs under `doas` **once** up front so root persists; enable/disable = add/remove `/service` symlink; no default keybind).
- **rebuild-kernel.sh** — Gentoo kernel rebuild ("lazygentoo", Secure Boot + UKI). Optionally updates `gentoo-sources` (`-e`), seeds + `olddefconfig`s `.config`, builds modules, rebuilds out-of-tree modules (`emerge @module-rebuild` — nvidia-drivers etc., else nvidia breaks every boot), `kernel-install add` (initramfs+UKI via `/etc/kernel/install.d` hooks), signs with ukify, prunes old UKIs, rewrites efibootmgr entry. Self-elevates via `doas`. `-y` skips prompt.
- **runbar.sh** — **stale/dead** (dwlb/someblocks; unbound).

## Services (runit)

Two scopes, managed by `svfzf` (user, `Super+Z`) / `ssvfzf` (system, `doas`) or `sv` directly.

**User** (`~/.local/sv`, supervised by per-user `runsvdir` from reach autostart; disable = drop a `down` file): `dbus` (persistent user D-Bus **session** bus — whole stack inherits it), `pipewire` (**group service**: pipewire + wireplumber + pipewire-pulse), `mpd` (**group service**: mpd + mpd-mpris), `emacs`, `quickshell` (widgets + wallpaper + lock + notifications + **clipboard/cliphist watchers**), `syncthing`, `wl-gammarelay-rs`. Manage via `svfzf` or `SVDIR=~/.local/sv sv <cmd> <name>`. **Group services** run several related daemons from one `run` script (`wait -n` → kill the group → runsv respawns all together), so a crash of any one restarts the set as a unit. (Clipboard capture used to be a standalone `cliphist` group service — now owned by quickshell's `Clipboard.qml`.)

**System** (`/etc/sv` → `/service`, **outside this repo**, not stowed): enable/disable via the `/service` symlink. Inspect on-box; typically greetd/tuigreet, ufw, bluetooth, dbus, udisks2.

## Music: MPD + rmpc

`de/.config/mpd/mpd.conf` — port 6600, `~/Music`, PipeWire (pulse backend) software mixer, 192kHz/24-bit, curl input on; runs as runit user service. MPRIS bridge is **`mpd-mpris`** (Go; media-sound/mpd-mpris), launched by the `mpd` **group service** (`mpd` + `mpd-mpris` together) — this is what exposes MPD on the MPRIS bus for the media keys and quickshell's `Mpd.qml`. Media keys (`XF86Audio{Play,Prev,Next}`) call `qs ipc call media {playpause,previous,next}` — an `IpcHandler` in `Mpd.qml` that drives the **MPD** MPRIS player specifically (matched by `dbusName` containing "mpd", never the active player). This replaced `playerctl -p mpd …`, so **media-sound/playerctl is no longer needed**. (The old `mpDris2` Python bridge and its `mpDris.conf` are **gone** — mpDris2 was never installed on this box; the leftover `mpDris2` service dir + config were removed.) rmpc `de/.config/rmpc/config.ron` — 127.0.0.1:6600, custom "miles" theme, vim nav, album art ≤1200px.

## Package Management

**Primary: Portage** — `sudo emerge -av <pkg>` (sudo→doas), `--unmerge`, `--search`/`eix`, `sudo emerge --sync && sudo emerge -avuDN @world` (update). **Secondary: Nix/home-manager** — `home-manager switch`, `nix-env -iA nixpkgs.<pkg>`, `nix-collect-garbage -d`. **Kernel:** `rebuild-kernel.sh`.

## Stale Void/DWL leftovers

Tracked for cleanup; none load-bearing on Gentoo + reach:
- `zsh/.zshrc` — `xi`/`xr`/`xu`/`xq` wrap `xbps-*` (repoint to `emerge`/`eix`).
- `fastfetch/config.jsonc` — Seat/Login Manager modules call `xbps-query` + scan `/var/service/` (this box uses `/service`); broken until rewritten for Portage.
- `runbar.sh` — dwlb/someblocks; dead, unbound.
- `yazi/yazi.toml` — `setbg` opener uses `swww img`; stale (system wallpaper is now `qs ipc call wallpaper set <path>`).
- `wireplumber/.../usb2-iec958.conf` — comment points to old `~/.local/src/dwl/autostart.sh` (now `flip.sh`).
- Cosmetic "dwl"/"Void" comments in `clipfzf`, `killfzf`, `svfzf`, `brightness.sh`, `~/.local/sv/emacs/run`.

## Git Workflow

`gs` (status -s) · `gac "msg"` (add . + commit) · `gp` (push). `.gitignore`: tmux plugins, UUID files, `lazy-lock.json`, MPD runtime files, `*.m3u`, nvim spell files.
