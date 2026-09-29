# CLAUDE.md

Guidance for Claude Code when working in this repo.

> Per-app keybinding/setting tables that simply mirror a config file have been trimmed to keep this file small. When you need exact keys/values, read the config at the path noted in each section. What's kept here is context **not** derivable from the files themselves (platform quirks, migration debt, cross-component wiring).

## Overview

Personal dotfiles for a **Gentoo Linux** system. Wayland stack centered on **reach** (a custom **Zig** river window manager; dwl-like — desktops, master/stack tiling, window rules; it draws no bar — state goes out over a socket for quickshell to draw). GNU Stow manages all symlinks from `de/` → `$HOME`. Terminal is **kitty**. Theme is **Catppuccin Mocha (Mauve accent)** everywhere. UI aesthetic: **flat/sharp** — `border-radius: 0` explicitly everywhere.

System package manager is **Portage** (`emerge`). Elevation is **`doas`** (`app-admin/doas`) — there is **no `sudo`** installed, and no sudo->doas symlink. doas matches a command **as typed against the rule as written** — `/etc/doas.conf` here carries `permit nopass :wheel cmd poweroff` (bare names, and miles is in `wheel`), so a caller must invoke the bare `poweroff`; passing `/usr/bin/poweroff` misses that rule and falls through to `permit persist :wheel`, which wants a password. (The `openvpn`/`kill` rules were written as absolute paths and needed the opposite — **the shell no longer uses either**: VPNs went NM-native, so nothing it runs elevates.) Check any invocation with `doas -C /etc/doas.conf <cmd>` — it prints `permit` / `permit nopass` / `deny` and executes nothing. `xbps`/`pacman`/`paru`/AUR do **not** apply. Nix + home-manager runs **alongside** Portage for a curated package set (security tools, GUI apps, Python libs). Clean nix with `nix-collect-garbage -d`.

> **Migration note:** previously Void Linux. Some configs still carry stale Void-era bits — see [Stale leftovers](#stale-voiddwl-leftovers).

## Repository Structure

```
de/                  # Stowed to $HOME
├── .config/         # App configs (incl. reach/, dconf/, quickshell/{bar,cards,launcher,monitors,music,wallpaper}/)
├── .local/bin/      # Custom scripts
├── .local/sv/       # Per-user runit service definitions
├── .local/share/    # Shared data (fonts, icons, GTK themes)
├── .zen/            # Zen browser chrome/userChrome.css
└── Documents/       # just logo.png — stowed to ~/Documents, referenced by nothing here
kernels/             # saved kernel .configs (desktop, old Intel laptop) — seeds for `rebuild-kernel.sh -c`; not stowed
tests/               # quickshell lint + QML unit tests (see Tests)
# nested CLAUDE.md files (reach/, quickshell/, quickshell/music/) load on demand
.claude/skills/      # project skills — `quickshell` covers editing and verifying the shell
screenshots/         # README screenshots
```

> The old `de/.local/src/` (dwl/dwlb/someblocks source) is **gone** — reach replaced the dwl stack and builds outside this repo.

## Installation & Setup

Old `install*.sh` bootstrap scripts were **removed**. Setup: `git clone` → `cd dotfiles` → `stow de` → `home-manager switch --flake ~/.config/home-manager#miles` (home-manager is a **flake** now — a bare `home-manager switch` has no config to find; the `nixup` alias is the update form). `stow -D de` removes symlinks. reach is configured purely by `de/.config/reach/config.zon` (no build step here). User runit services are picked up by the `runsvdir ~/.local/sv` reach autostart launches.

## Nix / home-manager

Runs alongside Portage for packages not easily/freshly available via emerge. It is a **flake** (`home-manager/flake.nix`, `homeConfigurations."miles"`, nixpkgs `nixos-unstable`): apply with `home-manager switch --flake ~/.config/home-manager#miles`, update with the `nixup` alias (`nix flake update` + switch). Configs:
- `home-manager/flake.nix` — inputs + `config.allowUnfree` + the **overlay**, which is where per-package breakage gets pinned down: `pipx` tests off, `evil-winrm` built against Ruby 3.3 (Ruby 3.4 dropped `csv` from default gems and its gemset lacks it), and a `pythonPackagesExtensions` override re-fetching `playwright` (nixpkgs pins a GitHub-generated tarball hash that GitHub regenerated — the fixed-output fetch fails and takes theharvester → `home-manager-path` → the whole generation with it, which is why a switch right after a flake update dies with *hash mismatch in fixed-output derivation*). Each override carries its reason in a comment; read them before dropping one.
- `home-manager/home.nix` — main (GUI apps, Python); imports `default.nix`. **Intentionally minimal** — no longer manages GTK theming/cursors/fonts/Qt (those are stowed directly + pushed via `dconf load`). Sets only one session var: `XDG_DATA_DIRS=/usr/local/share:/usr/share:$HOME/.nix-profile/share`. Declares `nix` itself in `home.packages` — home-manager rebuilds `~/.nix-profile` from that list on every switch, so an undeclared `nix` gets wiped off a single-user install. Also symlinks `proton-ge-bin`'s steamcompattool into Steam's `compatibilitytools.d` via `home.file` (its default output is a bare file, so it can't go in `home.packages`).
- `home-manager/default.nix` — thin entrypoint importing `modules/cyber.nix` + `modules/webdev.nix`.
- `home-manager/modules/webdev.nix` — course web toolchain: `nodejs_24` (pinned to the major), `mongodb-ce` (**not** `mongodb` — that builds the server from source via scons; the `-ce` attr unpacks upstream's prebuilt tarball), mongosh/tools, the html/css/json/eslint/ts LSPs the nvim setup expects, prettier, httpie.
- `home-manager/modules/virt.nix` — virt-manager/virt-viewer/spice-gtk. **NOT imported** by `default.nix`; add the import to use it.
- `home-manager/modules/cyber.nix` — security/pentest toolkit (`home.packages`): nmap, burpsuite, sqlmap, ffuf, feroxbuster, metasploit, exploitdb, hashcat, hydra, aircrack-ng, wireshark, bettercap, binaryninja-free, netexec, impacket, responder, etc. (full categorized list lives in the file). `netexec` is wrapped in an `overrideAttrs` that patches the `signing` kwarg out of `nxc/protocols/ldap.py` — nixpkgs pairs it with an impacket whose `LDAPConnection` has no such parameter, so every `nxc ldap` dies in `check_ldap_signing` with a TypeError. Also defines the `my.cyberPythonLibs` option consumed by `home.nix`.
- `home-manager/security-box/` — large per-category `*.nix` catalog, **NOT imported** by anything — staging/reference only.
- `nixpkgs/config.nix` — `{ allowUnfree = true; }` (burpsuite, wpscan, binaryninja-free). The flake sets `config.allowUnfree` itself, so this file only matters to `nix-env`/`nix shell` outside the flake.
- `home.nix` Python set includes `icalendar`, `recurring-ical-events`, `x-wr-timezone` which power the quickshell calendar widget, plus `config.my.cyberPythonLibs` — an option `cyber.nix` defines, so the pentest libraries (impacket, ldap3, pywinrm, …) land in the **same** interpreter as everything else instead of a second `python3.withPackages`.

> `hashcat` is installed via nix but the comment recommends the **system** `hashcat` for OpenCL/GPU driver compat.

> **nix GL vs system nvidia:** anything needing OpenGL/EGL/NVENC must come from **Portage**, not nix. The nvidia driver is Portage-managed (`/usr/lib64/libEGL_nvidia.so.*`), but nix binaries run under nix's `ld.so`, which never searches `/usr/lib64` — so the vendor ICD at `/usr/share/glvnd/egl_vendor.d/10_nvidia.json` resolves to nothing and EGL init dies (`eglGetDisplay failed` → *"Your GPU may not be supported"*). Pointing `LD_LIBRARY_PATH` at `/usr/lib64` doesn't fix it: it shadows nix libs with system ones and breaks the app earlier. Bridging the two properly is what `nixGL` exists for, and it works by shipping a *nix-built* driver matching the running kernel module — not by reusing the system one. **OBS lives in Portage for this reason** (`media-video/obs-studio`, USE `nvenc wayland screencast pulseaudio`); keep it out of `home.nix` or `~/.nix-profile/bin` will shadow `/usr/bin` on PATH.

## Catppuccin Mocha Palette

Base `#1e1e2e` (bg) · Surface0 `#313244` · Surface1 `#45475a` (borders) · Text `#cdd6f4` · Subtext0 `#a6adc8` · **Mauve `#cba6f7` (accent: focus/active)** · Overlay0 `#6c7086` (recessive text, a rank under Subtext0) · Overlay1 `#7f849c` (the bar's unselected desktop labels) · Blue `#89b4fa` · Green `#a6e3a1` · Peach `#fab387` (warn) · Red `#f38ba8` · Teal `#94e2d5` · Yellow `#f9e2af` · Lavender `#b4befe`.

## reach Window Manager

Custom Zig river WM, configured by `de/.config/reach/config.zon` (ZON). Full notes — reload semantics, pointer/output selection, gamma, monitor layouts, the state socket, env, window rules, keybinds — are in **`de/.config/reach/CLAUDE.md`**, loaded when you work there. What matters from anywhere:

- **An unknown key rejects the whole config.** A reload with a parse error keeps the running config, but at **startup** reach falls back to compiled-in defaults — no binds, no layout. A binary that adds or drops a key must land together with the config.zon that uses it.
- Reload: `Super+Shift+r` or `kill -HUP $(pidof reach)`. `.env` and `.autostart` are startup-only.
- **Monitor layouts** are files in `de/.config/reach/monitors/`; `monitors.zon` is a gitignored symlink to the active one (per-machine). Switch/edit them in quickshell's Displays window (`Super+R` `m`). A rotated head's `.w`/`.h` are its mode, not its footprint.
- **reach owns gamma** (brightness keys, night light via `.gamma.temperature` + reload). wl-gammarelay-rs / wlsunset / gammastep must not run, or its controls silently fail.
- reach draws **no bar**: it publishes JSON snapshots on `$XDG_RUNTIME_DIR/reach.sock` (write-only) and quickshell draws the bar.
- The `.env` block puts `~/.nix-profile` first on `PATH`/`XDG_DATA_DIRS` — greetd doesn't hand the nix profile down, and a bind spawning a nix binary would otherwise do nothing.
- Keybinds live in config.zon: a `.binds` block replaces the whole default keymap except the per-desktop digit binds. Window rules: `desktop` is 1-based, `monitor` is an index into the active layout, and quickshell's windows share the app_id `org.quickshell`, so rules must also match the title.

## Per-app configs (read the file for exact keys/values)

- **Shell (ZSH)** — `de/.config/zsh/.zshrc` + `.zshenv`. zplug loads three plugins: `zsh-vi-mode`, **`zhimmer`** and `zsh-syntax-highlighting`. zhimmer is a **local** plugin (`zplug "$HOME/Projects/zhimmer", from:local`, `defer:2`) — not in this repo, and a missing `~/Projects/zhimmer` just means no completion drop-down and no prompt. It replaced spaceship, zsh-autosuggestions and fzf-tab all at once: it draws its own drop-down (so `complist`/`menu-style` no longer applies) and provides the prompt (`zstyle ':zhimmer:*' prompt yes`); sources are `history alias command file git-branch zoxide`. `EDITOR=nvim`, `MANPAGER="nvim +Man!"`, all tool homes redirect to `XDG_DATA_HOME`. Aliases: `gs`/`gac`/`gp`/`gl` (git), `y` (yazi+cd), `esync`/`eworld` (Portage), `nixup` (flake update + home-manager switch) / `nixgc`, `c`/`cs` (claude), `x` (codex), `ff` (fastfetch).
  - **Ctrl+R is deliberately unbound in four keymaps**, and the comment explaining why was dropped from the file: fzf binds it in all of them, so removing it from the current keymap alone left it reachable — Esc to cancel a search drops into vi normal mode, where `vicmd` still had fzf's widget. zhimmer takes over `emacs` and `viins` itself; `vicmd '^R'` is put back to `redo`, which is what fzf took it from.
  - `.zshenv` clears `__ETC_PROFILE_NIX_SOURCED` before Gentoo's `/etc/zsh/zprofile` runs: baselayout's `/etc/profile.env` re-exports a `PATH` with no nix in it, and `nix-daemon.sh` self-skips on that guard var — so without the unset, nix vanishes from every **login** shell (ttys, tmux).
- **kitty** — `de/.config/kitty/kitty.conf`. JetBrainsMono Nerd Font 12, 1M scrollback, decorations hidden, Catppuccin Mocha. Window class used by reach binds: `float` (fzf pickers).
- **tmux** — `de/.config/tmux/tmux.conf`. Prefix `Ctrl+F`, base index 1, mouse on, zsh. Plugins via tpm: catppuccin, sensible, resurrect, continuum.
- **Neovim** — `de/.config/nvim/`. lazy.nvim. Leader `Space`, tab=4 expandtab, system clipboard, nvim-tree (right, no netrw), telescope, treesitter, lspconfig+mason (lua_ls, pyright), nvim-cmp, catppuccin. Spell en_us for md/text.
- **rofi** — **gone**. `de/.config/rofi/` and the `spotlight-dark.rasi` theme were both deleted (commit `4def71a2`); `Launcher.qml` owns `Super+Space`. `gui-apps/rofi-wayland` is still merged but nothing in this repo invokes it.
- **yazi** — `de/.config/yazi/`. Hidden shown, vim nav. Openers: nvim/xdg-open/swayimg/zathura/mpv. Plugins: git, piper, mount, chmod. The `setbg` opener (`O` on an image) runs `qs ipc call wallpaper set "$1"`.
- **btop** — `de/.config/btop/btop.conf`. mocha theme, GPU nvidia/amd/intel.
- **Zen browser** — `de/.zen/` (userChrome.css + user.js, custom CSS enabled). (`de/.config/mimeapps.list` is **gone** — default-application handling is the system's now.)
- **beets** — `de/.config/beets/config.yaml`. Owns canonical MusicBrainz metadata **and** the on-disk layout of `~/Music` (`directory: ~/Music`, `import.move: yes`, incremental). Split of duties with the separate `~/mux` tool is written into the file's header and matters: **mux dedupes** (it hashes decoded audio — beets' `duplicates` plugin keys on tags/MBIDs, which is exactly what's inconsistent here) and owns `.lrc` sidecars; **beets** owns layout and the library db. Run `mux dedupe` **first**, and never `mux organize` — two owners of layout is how a library gets shredded. The unreleased/leaks `paths` rule must stay first or an import silently re-files what `mux unreleased` shelved.
- **xdg portals** — `de/.config/xdg-desktop-portal/portals.conf` sets `default=wlr;gtk` (wlr first, so screencast/screenshot go to the wlroots backend and file dialogs fall through to gtk); `de/.config/xdg-desktop-portal-wlr/config` picks the output/region with `slurp -f %o -or`.

## Quickshell (desktop shell)

`de/.config/quickshell/` is the whole desktop UI — bar, cards, launcher, pickers, lock screen, notifications, OSD, wallpaper, music player, display configurator. Per-component notes are in **`de/.config/quickshell/CLAUDE.md`** (music player: `music/CLAUDE.md`), loaded when you work there; the **`quickshell` skill** is the how-to (constraints, conventions, templates, verifying). Always relevant:

- `shell.qml` is one `LazyLoader { active: Config.on("<key>") }` per feature. Which features are **off** is per-machine state in `~/.local/state/quickshell/features.json` (outside the repo), toggled from the settings menu (`Super+Shift+Escape`).
- Runs as the runit user service `quickshell` with `QT_QUICK_BACKEND=software`, so GPU-only QML (`ShaderEffect`, `MultiEffect`, `layer.effect`) draws nothing. Restart with `SVDIR=~/.local/sv sv restart quickshell` — required after editing a `.js` library, and whenever hot reload goes stale.
- IPC: `qs ipc call <target> toggle|hide|open` — never `show`, which the CLI swallows as `qs ipc show`.
- Deps: nvidia-smi, curl, python3 + icalendar + recurring-ical-events (from home-manager). No `jq`.

## GTK / Qt Theming

Flat (`border-radius: 0` global, enforced in `gtk-3.0/gtk.css`). GTK3/GTK4 are **stowed directly** as plain files (no longer home-manager–generated) — edit repo files + re-stow. Theme `catppuccin-mocha-mauve-standard+default`, icons **Papirus-Dark**, font JetBrainsMono Nerd Font, cursor Bibata-Modern-Classic.

- `de/.config/dconf/interface.dconf` — `dconf load`ed into `/org/gnome/desktop/interface/` by reach autostart (GTK apps reading GNOME settings).
- **No xsettingsd.** Its config was removed: the binary was never installed and nothing launched it, so the XSETTINGS it described were never applied. Dark mode reaches apps through `color-scheme='prefer-dark'` in `interface.dconf` instead.
- Qt6 `de/.config/qt6ct/qt6ct.conf` (style Kvantum, catppuccin-mocha-mauve) + Kvantum `de/.config/Kvantum/kvantum.kvconfig`.

## Audio: PipeWire + WirePlumber

**Config:** `de/.config/pipewire/` + `de/.config/wireplumber/`. PipeWire/WirePlumber/pipewire-pulse run as runit user services.

- `pipewire.conf.d/custom.conf` — `default.clock.rate = 192000`, `allowed-rates = [192000]`, `link.max-buffers = 16`.
- `pipewire.conf.d/sink-eq.conf` — 16-band parametric EQ via builtin `filter-chain` (replaces EasyEffects). Two EQ sinks pinned via `target.object` to specific hardware: `effect_input.eq_fiio` → FiiO K11 USB DAC, `effect_input.eq_optical` → USB2.0 optical. All bands `bq_peaking`, Q=2.3521, APO(DR); coefficients mirror old `easyeffects/output/EQ.json`. **Keep both instances' coefficients in sync if regenerating.** Verify: `wpctl status | grep -E "effect_input\.eq_(fiio|optical)"`.
- `wireplumber.conf.d/softvol.conf` — `api.alsa.soft-mixer = true` for all USB cards (`alsa_card.usb-.*`); required for USB software volume.

**EQ switching:** apps connect to the default sink; `~/.local/bin/flip.sh` (`Alt+[`) cycles the default between the two `effect_input.eq_*` sinks and migrates playing streams; `flip.sh set <sink>` switches to a named one (what the quickshell audio menu calls). Raw `alsa_output.*` sinks excluded (pick those via wpctl/pavucontrol to bypass EQ).

## Custom Scripts (`de/.local/bin/`)

- **screenshot.sh** — `ss` (region → clipboard), `section` (region → file → satty), `region` (region → file), `<output>` (any name grim accepts → file → satty). Output `~/Pictures/screenshot-*.png`. **Exits non-zero whenever nothing was captured** (a cancelled `slurp` included) — both the `Super+S` chord and `Screenshot.qml` chain `&& notify-send`, so a cancel must stay silent. The chord still names outputs literally (`0`→eDP-1, `1`–`3`→DP-1..3); the quickshell menu is the per-machine way.
- **flip.sh** — no args cycles the default sink between the two EQ sinks; `set <sink>` switches to a named one (including the raw `alsa_output.*` sinks the cycle steps over) for the quickshell audio menu. Both paths set the USB2.0 card to `iec958-stereo` first so the optical chain's `target.object` resolves, migrate playing streams (only those with an `application.name` — never the filter chains' own inputs). `Alt+[`. (No longer signals reach — the bar's sink name comes from Pipewire now, so it updates on its own.)
- **wallpaper-thumbs** — pre-renders 400x225 JPEG thumbnails of `~/Pictures/bgs` into `$XDG_CACHE_HOME/wallpaper-thumbs` for the quickshell picker; idempotent (only missing/stale files are rendered), fans out via `xargs` re-entering itself as a worker. `--list` emits `category<TAB>source<TAB>thumb` — the picker's only source of thumb paths.
- **killfzf** — `ps --forest` → fzf; Enter=SIGTERM, Ctrl-K=SIGKILL, Tab=multi. `Super+X`.
- **svfzf / ssvfzf** — two runit service managers (floating kitty + fzf; glyphs ●/○/·). **Split in two** because per-call `doas` prompts broke inside the fzf action loop (stdin is the pick pipeline). `svfzf` = **user** services in `~/.local/sv` (no elevation; enable/disable = `rm`/`touch` a `down` file; `Super+Z`). `ssvfzf` = **system** services in `/etc/sv` (re-execs under `doas` **once** up front so root persists; enable/disable = add/remove `/service` symlink; no default keybind).
- **rebuild-kernel.sh** — Gentoo kernel rebuild ("lazygentoo", Secure Boot + UKI). Optionally updates `gentoo-sources` (`-e`), seeds + `olddefconfig`s `.config`, builds modules, rebuilds out-of-tree modules (`emerge @module-rebuild` — nvidia-drivers etc., else nvidia breaks every boot), `kernel-install add` (initramfs+UKI via `/etc/kernel/install.d` hooks), signs with ukify, prunes old UKIs, rewrites efibootmgr entry. Self-elevates via `doas`. `-y` skips prompt.

## Services (runit)

Two scopes, managed by `svfzf` (user, `Super+Z`) / `ssvfzf` (system, `doas`) or `sv` directly.

**User** (`~/.local/sv`, supervised by per-user `runsvdir` from reach autostart; disable = drop a `down` file): `dbus` (persistent user D-Bus **session** bus — whole stack inherits it), `pipewire` (**group service**: pipewire + wireplumber + pipewire-pulse), `mpd` (**group service**: mpd + mpd-mpris), `quickshell` (widgets + wallpaper + lock + notifications + **clipboard/cliphist watchers**), `syncthing`. Manage via `svfzf` or `SVDIR=~/.local/sv sv <cmd> <name>`. **Group services** run several related daemons from one `run` script (`wait -n` → kill the group → runsv respawns all together), so a crash of any one restarts the set as a unit. (Clipboard capture used to be a standalone `cliphist` group service — now owned by quickshell's `Clipboard.qml`.)

**System** (`/etc/sv` → `/service`, **outside this repo**, not stowed): enable/disable via the `/service` symlink. Inspect on-box; typically greetd/tuigreet, ufw, bluetooth, dbus, udisks2.

## Music: MPD

`de/.config/mpd/mpd.conf` — port 6600, `~/Music`, PipeWire (pulse backend) software mixer, 192kHz/24-bit, curl input on; runs as runit user service. MPRIS bridge is **`mpd-mpris`** (Go; media-sound/mpd-mpris), launched by the `mpd` **group service** (`mpd` + `mpd-mpris` together) — this is what exposes MPD on the MPRIS bus for the media keys and quickshell's `Mpd.qml`. Media keys (`XF86Audio{Play,Prev,Next}`) call `qs ipc call media {playpause,previous,next}` — an `IpcHandler` in `Mpd.qml` that drives the **MPD** MPRIS player specifically (matched by `dbusName` containing "mpd", never the active player). This replaced `playerctl -p mpd …`, so **media-sound/playerctl is no longer needed**. (The old `mpDris2` Python bridge and its `mpDris.conf` are **gone** — mpDris2 was never installed on this box; the leftover `mpDris2` service dir + config were removed.) **rmpc is gone** — package unmerged and `de/.config/rmpc/` deleted. quickshell's native client is the only one; its notes are in `de/.config/quickshell/music/CLAUDE.md`. Its keymap was lifted from the old rmpc config, which is why rmpc is still cited below as the reference for key choices.

## Package Management

**Primary: Portage** — `doas emerge -av <pkg>`, `--unmerge`, `--search`/`eix`, `doas emerge --sync && doas emerge -avuDN @world` (update). **Secondary: Nix/home-manager** — `home-manager switch`, `nix-env -iA nixpkgs.<pkg>`, `nix-collect-garbage -d`. **Kernel:** `rebuild-kernel.sh`.

## Stale Void/DWL leftovers

None left: the last ones (fastfetch's `xbps-query` modules, yazi's `swww` opener, dwl-era
comments, the never-installed xsettingsd) were fixed or removed on 2026-09-25. Add new finds here.
> **Not stale, despite a previous note here:** `zsh/.zshenv`'s `$HOME/.config/emacs/bin`
> on `PATH` is live — `app-editors/emacs` is installed and `~/.config/emacs` is a Doom
> checkout whose `bin/` holds `doom`, `doom-sync`, `doom-doctor`. Only the runit service
> and the shell aliases were removed (commit `aa4b679f`). Leave the PATH entry alone.

## Tests

`tests/run.sh` runs `tests/lint.sh` and then the QML unit tests (`tests/quickshell/tst_*.qml`: `FileSearch`, `MusicController`) under `qmltestrunner`, which Gentoo installs **off PATH** at `/usr/lib64/qt6/bin/`. A TestCase name or flag (`tests/run.sh MusicController`, `-functions`) skips the lint. Units must import only QtQuick — Quickshell's plugin is linked into `qs` and can't be loaded — and the runner stages copies so a sibling `qmldir` doesn't drag Quickshell in; each script's header explains the details. `lint.sh` fails on qmllint's `syntax`/`unqualified`/`property-override`/`unused-imports`, a missing `ComponentBehavior: Bound`, or an `IpcHandler` exposing `show()`; its other ~470 warnings are noise it filters out.

## Git Workflow

`gs` (status -s) · `gac "msg"` (add . + commit) · `gp` (push). `.gitignore`: tmux plugins, UUID files, `lazy-lock.json`, MPD runtime files, `*.m3u`, nvim spell files.
