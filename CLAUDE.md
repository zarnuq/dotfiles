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

> The old `de/.local/src/` (dwl/dwlb/someblocks source) is **gone** — reach replaced the dwl stack and builds outside this repo. `de/.config/eww.bak/` is a leftover backup dir.

## Installation & Setup

Old `install*.sh` bootstrap scripts were **removed**. Setup: `git clone` → `cd dotfiles` → `stow de` → `home-manager switch`. `stow -D de` removes symlinks. reach is configured purely by `de/.config/reach/config.zon` (no build step here). User runit services are picked up by the `runsvdir ~/.local/sv` reach autostart launches.

## Nix / home-manager

Runs alongside Portage for packages not easily/freshly available via emerge. `home-manager switch` applies. Configs:
- `home-manager/home.nix` — main (GUI apps, Python); imports `default.nix`. **Intentionally minimal** — no longer manages GTK theming/cursors/fonts/Qt (those are stowed directly + pushed via `dconf load`). Sets only one session var: `XDG_DATA_DIRS=/usr/local/share:/usr/share:$HOME/.nix-profile/share`.
- `home-manager/default.nix` — thin entrypoint importing `modules/cyber.nix`.
- `home-manager/modules/cyber.nix` — security/pentest toolkit (`home.packages`): nmap, burpsuite, sqlmap, ffuf, feroxbuster, metasploit, hashcat, hydra, aircrack-ng, wireshark, bettercap, binaryninja-free, netexec, impacket, responder, etc. (full categorized list lives in the file).
- `home-manager/security-box/` — large per-category `*.nix` catalog, **NOT imported** by anything — staging/reference only.
- `nixpkgs/config.nix` — `{ allowUnfree = true; }` (needed for burpsuite, wpscan, binaryninja-free).
- `home.nix` Python set includes `icalendar`, `recurring-ical-events`, `x-wr-timezone` which power the eww calendar widget; `pipx` has tests disabled via override (suite breaks on newer `packaging`).

> `hashcat` is installed via nix but the comment recommends the **system** `hashcat` for OpenCL/GPU driver compat.

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

**Keybinds:** `Super`=Mod. A `.binds` block **replaces the entire** default action/spawn/chord keymap **except** the auto-generated per-tag digit binds (`Super`/`+Ctrl`/`+Shift` + `1`–`9` = view/toggle/move, never listed in config). See `config.zon` for the full map. Notable: launchers (`Super+Tab` kitty, `Super+Space` rofi, `Super+V` clipfzf, `Super+X` killfzf, `Super+Z` svfzf), `Super+r`/`Super+s` two-key chords (apps / screenshots), `Alt+[` cycle EQ sink, `Super+Alt+Left/Right` brightness, `Super+Alt+Up` night-light toggle.

> **Broken bind:** `Super+E`/`Super+Shift+E` spawn `~/.local/bin/eww.sh`, which **no longer exists** (eww is a runit service now). Rebind or restore.

## Per-app configs (read the file for exact keys/values)

- **Shell (ZSH)** — `de/.config/zsh/.zshrc` + `.zshenv`. zplug (syntax-highlight, autosuggestions, fzf-tab, spaceship, vi-mode). `EDITOR=nvim`, all tool homes redirect to `XDG_DATA_HOME`. Aliases: `gs`/`gac`/`gp` (git), `y` (yazi+cd), `doomsync` (restart emacs service + doom sync). `xi`/`xr`/`xu`/`xq` are **stale Void xbps wrappers** (see leftovers).
- **kitty** — `de/.config/kitty/kitty.conf`. JetBrainsMono Nerd Font 12, 1M scrollback, decorations hidden, Catppuccin Mocha. Window classes used by reach binds: `float` (fzf pickers), `rmpc` (music).
- **tmux** — `de/.config/tmux/tmux.conf`. Prefix `Ctrl+F`, base index 1, mouse on, zsh. Plugins via tpm: catppuccin, sensible, resurrect, continuum.
- **Neovim** — `de/.config/nvim/`. lazy.nvim. Leader `Space`, tab=4 expandtab, system clipboard, nvim-tree (right, no netrw), telescope, treesitter, lspconfig+mason (lua_ls, pyright), nvim-cmp, catppuccin. Spell en_us for md/text.
- **Doom Emacs** — `de/.config/doom/`. catppuccin, org `~/org/`, both PRIMARY+clipboard sync `t`. Runs as runit **user service** (`~/.local/sv/emacs`); `Super+D` opens `emacsclient -c`; `doomsync` = kill → `sv stop emacs` → doom sync → `sv start emacs`.
- **rofi** — `de/.config/rofi/config.rasi`, rofi-**wayland**, theme `spotlight-dark.rasi`.
- **yazi** — `de/.config/yazi/`. Hidden shown, vim nav. Openers: nvim/xdg-open/loupe/zathura/mpv. Plugins: git, piper, mount, chmod. `setbg` opener uses `swww img` — **stale**, system uses `awww`.
- **btop** — `de/.config/btop/btop.conf`. mocha theme, GPU nvidia/amd/intel.
- **swaylock** — `de/.config/swaylock/config`. Triggered by `Super+P` and the `swayidle` user service (300s idle).
- **Zen browser** — `de/.zen/` (userChrome.css + user.js, custom CSS enabled). `de/.config/mimeapps.list`: default browser zen, Discord→legcord.

## EWW Desktop Widgets

**Config:** `de/.config/eww/` — single dir (`dash/` subdir gone; `eww.bak/` is a backup). `eww.yuck` (widgets/windows), `eww.scss` (`@import "scale"` → reads generated `_scale.scss`), `scripts/` (data providers), `calendar.url` (ICS/CalDAV URL).

**Launch:** eww daemon + dashboard live in the `eww` **runit user service** (`~/.local/sv/eww/run`) — **no `eww.sh`**. The service waits for dbus+wayland sockets, exports `WAYLAND_DISPLAY`, detects monitor/scale (`DP-2` present → mon 1 desktop scale `1.0`; else mon 0 laptop scale `0.85`), writes `_scale.scss`, reloads SCSS, opens every window once with `--screen <mon> --arg scale=<scale>`, then `exec`s `eww daemon --no-daemonize` so runsv supervises the long-lived daemon (not the flapping one-shot open). `scale` drives **both** CSS sizes (`s(n)` helper) and window geometry (per-window arg, since `:geometry` can't read globals). `$border-radius: 0px` (flat).

**Windows launched (11):** `clock cpu net-graph tray weather notifications mpd outlook ports vpn brightness`. Notable wiring: `cpu` overlays CPU/RAM/disk + nvidia-smi GPU + `/sys/class/thermal`; `net-graph` parses `/proc/net/dev` + `ip -j addr`; `notifications` uses `makoctl history -j` + DND toggle; `mpd` embeds the **volume sliders** `(volume)` widget (not a standalone window); `brightness` is a software slider for ALL outputs via `wl-gammarelay-rs`; `outlook` is the ICS calendar.

**Scripts** (`de/.config/eww/scripts/`): `ports.sh` (ss+jq), `calendar.sh` (Python; needs `icalendar`+`recurring_ical_events` from home-manager; reads `calendar.url`, caches to `/tmp/eww-calendar.ics`), `vpn-manager.sh` (OpenVPN; state in `/tmp/eww-openvpn.*`), `focused-output.sh`.

**Deps:** jq, wl-gammarelay-rs+gdbus, mpc, wpctl, makoctl, nvidia-smi, curl, python3+icalendar+recurring-ical-events, wlr-randr.

## Notification Daemon: mako

**Config:** `de/.config/mako/config`. Replaced dunst. Wayland-native; `makoctl` talks D-Bus directly via basu (no busctl/systemd). Needs only the D-Bus **session bus** reach provides (pinned via `DBUS_SESSION_BUS_ADDRESS`); runs as runit user service (`~/.local/sv/mako`) and inherits the bus.

> Running `mako`/`makoctl`/`notify-send` from a terminal lacking that env (e.g. one surviving a session restart) fails with "Could not connect" — open a fresh terminal under the session. `notify-send` needs `libnotify`.

Flat (border-radius 0), top-right, mauve border (peach + no-timeout for critical). `max-history=20`; mako has **no "clear history"** — the eww clear button maps to `makoctl dismiss -a` (clears on-screen only). DND is a **mode** (`makoctl mode -t do-not-disturb`).

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
- **brightness.sh** — software brightness for ALL outputs (incl. DP/HDMI w/o `/sys/class/backlight`) via wl-gammarelay-rs gamma dimming (session bus, no root/i2c). `up`/`down`/`set <0-100>`/`get`; floor 10%. Drives the eww brightness widget; `Super+Alt+Left/Right`.
- **clipfzf** — `cliphist list | fzf | cliphist decode | wl-copy`. `Super+V`.
- **killfzf** — `ps --forest` → fzf; Enter=SIGTERM, Ctrl-K=SIGKILL, Tab=multi. `Super+X`.
- **svfzf / ssvfzf** — two runit service managers (floating kitty + fzf; glyphs ●/○/·). **Split in two** because per-call `doas` prompts broke inside the fzf action loop (stdin is the pick pipeline). `svfzf` = **user** services in `~/.local/sv` (no elevation; enable/disable = `rm`/`touch` a `down` file; `Super+Z`). `ssvfzf` = **system** services in `/etc/sv` (re-execs under `doas` **once** up front so root persists; enable/disable = add/remove `/service` symlink; no default keybind).
- **rebuild-kernel.sh** — Gentoo kernel rebuild ("lazygentoo", Secure Boot + UKI). Optionally updates `gentoo-sources` (`-e`), seeds + `olddefconfig`s `.config`, builds modules, `kernel-install add` (initramfs+UKI via `/etc/kernel/install.d` hooks), signs with ukify, prunes old UKIs, rewrites efibootmgr entry. Self-elevates via `doas`. `-y` skips prompt.
- **runbar.sh** — **stale/dead** (dwlb/someblocks; unbound).

## Services (runit)

Two scopes, managed by `svfzf` (user, `Super+Z`) / `ssvfzf` (system, `doas`) or `sv` directly.

**User** (`~/.local/sv`, supervised by per-user `runsvdir` from reach autostart; disable = drop a `down` file): `dbus` (persistent user D-Bus **session** bus — whole stack inherits it), `pipewire`/`pipewire-pulse`/`wireplumber`, `mpd`, `mpDris2`, `emacs`, `eww`, `mako`, `awww` (wallpaper), `syncthing`, `wl-gammarelay-rs`, `swayidle` (300s → swaylock), `cliphist-text`/`cliphist-image`. Manage via `svfzf` or `SVDIR=~/.local/sv sv <cmd> <name>`.

**System** (`/etc/sv` → `/service`, **outside this repo**, not stowed): enable/disable via the `/service` symlink. Inspect on-box; typically greetd/tuigreet, ufw, bluetooth, dbus, udisks2.

## Music: MPD + rmpc

`de/.config/mpd/mpd.conf` — port 6600, `~/Music`, PipeWire (pulse backend) software mixer, 192kHz/24-bit, curl input on; runs as runit user service. `mpDris.conf` → runit service `mpDris2`. rmpc `de/.config/rmpc/config.ron` — 127.0.0.1:6600, custom "miles" theme, vim nav, album art ≤1200px.

## Package Management

**Primary: Portage** — `sudo emerge -av <pkg>` (sudo→doas), `--unmerge`, `--search`/`eix`, `sudo emerge --sync && sudo emerge -avuDN @world` (update). **Secondary: Nix/home-manager** — `home-manager switch`, `nix-env -iA nixpkgs.<pkg>`, `nix-collect-garbage -d`. **Kernel:** `rebuild-kernel.sh`.

## Stale Void/DWL leftovers

Tracked for cleanup; none load-bearing on Gentoo + reach:
- `zsh/.zshrc` — `xi`/`xr`/`xu`/`xq` wrap `xbps-*` (repoint to `emerge`/`eix`).
- `fastfetch/config.jsonc` — Seat/Login Manager modules call `xbps-query` + scan `/var/service/` (this box uses `/service`); broken until rewritten for Portage.
- `runbar.sh` — dwlb/someblocks; dead, unbound.
- `yazi/yazi.toml` — `setbg` uses `swww img` (system uses `awww`).
- `wireplumber/.../usb2-iec958.conf` — comment points to old `~/.local/src/dwl/autostart.sh` (now `flip.sh`).
- `~/.local/bin/eww.sh` — referenced by reach `Super+E`/`Super+Shift+E` but doesn't exist (eww is a service); rebind/restore.
- `de/.config/eww.bak/` — old eww layout backup.
- Cosmetic "dwl"/"Void" comments in `clipfzf`, `killfzf`, `svfzf`, `brightness.sh`, `~/.local/sv/emacs/run`.

## Git Workflow

`gs` (status -s) · `gac "msg"` (add . + commit) · `gp` (push). `.gitignore`: tmux plugins, UUID files, `lazy-lock.json`, MPD runtime files, `*.m3u`, nvim spell files.
