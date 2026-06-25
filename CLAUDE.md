# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal dotfiles for a **Gentoo Linux** system. Wayland compositor stack centered on **reach** (a custom Zig Wayland compositor; dwl-like — tags, master/stack tiling, a baked-in someblocks-style status bar). GNU Stow manages all symlinks from `de/` to `$HOME`. Terminal emulator is **kitty** (not ghostty, not wezterm). Theme is **Catppuccin Mocha (Mauve accent)** across all applications. UI aesthetic: **flat/sharp** — all border-radius is explicitly 0 everywhere.

System package manager is **Portage** (`emerge`). `sudo` is symlinked to **`doas`** on this box. `xbps`/`pacman`/`paru`/AUR do **not** apply. Nix + home-manager is used alongside Portage for a curated set of packages (security tools in `modules/cyber.nix`, GUI apps, Python libs — see [Nix / home-manager](#nix--home-manager) section). Clean nix garbage with `nix-collect-garbage -d`.

> **Migration note:** this box was previously Void Linux. Some configs still carry Void-era bits that are now stale and may break or no-op on Gentoo — see [Stale Void/DWL leftovers](#stale-voiddwl-leftovers).

---

## Repository Structure

```
dotfiles/
├── de/                        # Stowed to $HOME
│   ├── .config/               # Application configs (incl. reach/, dconf/)
│   ├── .local/bin/            # Custom scripts
│   ├── .local/sv/             # Per-user runit service definitions
│   ├── .local/share/          # Shared data (icons, rofi themes)
│   └── .zen/                  # Zen browser chrome/userChrome.css
├── archive/                   # Archived old configs
└── screenshots/               # README screenshots
```

> The old `de/.local/src/` (dwl/dwlb/someblocks source) is **gone** — reach replaced the dwl stack and is installed/built outside this repo. `de/.config/eww.bak/` is a leftover backup dir.

---

## Installation & Setup

The old `install.sh` / `install-tui.sh` bootstrap scripts have been **removed**. Setup is now: clone, stow, then apply the nix/home-manager and runit layers manually.

```bash
cd ~
git clone https://github.com/zarnuq/dotfiles.git
cd dotfiles
stow de
home-manager switch            # nix-managed packages (see Nix section)
```

### Stow Commands
```bash
stow de      # apply all symlinks
stow -D de   # remove all symlinks
```

reach itself is configured by `de/.config/reach/config.zon` (no build step in this repo). User services are picked up by the `runsvdir ~/.local/sv` that reach's autostart launches.

---

## Nix / home-manager

**Configs:**
- `de/.config/home-manager/home.nix` — main config (GUI apps, Python ecosystem); imports `default.nix`
- `de/.config/home-manager/default.nix` — thin entrypoint that imports `./modules/cyber.nix`
- `de/.config/home-manager/modules/cyber.nix` — security / pentesting toolkit (`home.packages`)
- `de/.config/home-manager/security-box/` — a large library of per-category `*.nix` package sets (NixOS-style `environment.systemPackages`). **Not imported** by `default.nix`/`home.nix` — it's a staging/reference catalog, not active config.
- `de/.config/home-manager/flake.nix` / `flake.lock` — flake pinning inputs
- `de/.config/nixpkgs/config.nix` — `{ allowUnfree = true; }` (required for burpsuite, wpscan, binaryninja-free, etc.)

Home-manager runs **alongside** Portage to manage a curated set of packages not easily available or kept up-to-date via emerge. Run `home-manager switch` to apply.

> **Note:** `home.nix` is intentionally minimal — it no longer manages GTK theming (`gtk.enable`), cursors, fonts, or Qt/Kvantum plugins. GTK theming is stowed directly (see [GTK / Qt Theming](#gtk--qt-theming)) and also pushed into GNOME/GTK settings via `dconf load` in reach's autostart. EasyEffects was dropped in favor of a PipeWire filter-chain EQ (see [Audio](#audio-pipewire--wireplumber)).

### Session Variables (set by home.nix)
- `XDG_DATA_DIRS=/usr/local/share:/usr/share:$HOME/.nix-profile/share`

(This is the only session variable home.nix sets. Qt/desktop env vars are set by reach's `env` block — see [reach Environment](#environment-variables-set-by-reach).)

### home.nix Packages (GUI + Python)
- GUI / CLI apps: `chromium`, `firefox-bin`, `claude-code`, `kiro-cli`, `antigravity`, `termius`, `nwg-look`, `unhide`, `wl-gammarelay-rs`
- LaTeX: `texlive.combine { scheme-medium + latexmk }`
- Python: `python3.withPackages` → `impacket`, `virtualenv`, `pip`, `icalendar`, `recurring-ical-events`, `x-wr-timezone` (last three power the eww calendar widget)
- `pipx` (tests disabled via `overridePythonAttrs` — pipx 1.8.0's suite breaks on newer `packaging`)

### Security / Pentesting Toolkit (`modules/cyber.nix`)

Imported by `default.nix`, providing `home.packages`:

| Category              | Tools                                                                                    |
|-----------------------|------------------------------------------------------------------------------------------|
| RECON & OSINT         | enum4linux, theharvester, whois, dnsrecon                                                |
| SCANNING & ENUM       | nmap, onesixtyone, nikto, snmpcheck, nuclei                                              |
| WEB APP TESTING       | burpsuite, sqlmap, gobuster, ffuf, feroxbuster, wfuzz, whatweb, wpscan                  |
| EXPLOITATION          | metasploit, exploitdb (searchsploit)                                                     |
| PASSWORD ATTACKS      | hashcat, thc-hydra, ncrack, medusa, crunch, chntpw, fcrackzip (john commented out — use system john) |
| WIRELESS              | aircrack-ng, kismet, macchanger, iw, bluez                                               |
| SNIFFING & MITM       | wireshark, tcpdump, bettercap                                                            |
| POST-EXPLOIT/TUNNEL   | netcat-openbsd, openvpn, evil-winrm                                                      |
| REVERSE ENGINEERING   | binaryninja-free, gdb                                                                    |
| FORENSICS & RECOVERY  | binwalk                                                                                  |
| CRYPTO & STEGO        | steghide, stegseek                                                                       |
| UTILITIES             | unrar, dos2unix, ethtool, inetutils, exiftool, responder, netexec, smbclient-ng         |

> **Note:** `hashcat` is installed via nix but the comment recommends the system `hashcat` for OpenCL/GPU driver compatibility.

---

## Catppuccin Mocha Color Palette

Used consistently across ALL applications:

| Name       | Hex       | Usage                          |
|------------|-----------|-------------------------------|
| Base       | #1e1e2e   | Window/panel backgrounds       |
| Surface0   | #313244   | Buttons, input fields          |
| Surface1   | #45475a   | Borders, separators            |
| Text       | #cdd6f4   | Primary text                   |
| Subtext0   | #a6adc8   | Secondary/muted text           |
| Subtext1   | #bac2de   | Slightly less muted text       |
| Mauve      | #cba6f7   | Accent: focus, active, borders |
| Blue       | #89b4fa   | Info, links, focused border    |
| Green      | #a6e3a1   | Success                        |
| Peach      | #fab387   | Warnings                       |
| Red        | #f38ba8   | Errors, critical               |
| Teal       | #94e2d5   | Alternate accent               |
| Yellow     | #f9e2af   | Misc highlights                |
| Lavender   | #b4befe   | Soft accent                    |

---

## reach Window Manager

reach is a custom **Zig** Wayland compositor that fills the role dwl/dwlb/someblocks used to: dynamic tags, master/stack tiling, a monocle-style fullscreen, regex window rules, monitor layout, and an **in-process** status bar (someblocks-style). It maps closely to dwl concepts (the config comments cross-reference them).

**Config:** `de/.config/reach/config.zon` — ZON (Zig Object Notation). Read **once at startup**. Every field is optional; anything omitted falls back to the compiled-in default (`config.zig`). Lookup order (first found wins): `$XDG_CONFIG_HOME/reach/config.zon`, `~/.config/reach/config.zon`, `/etc/reach/config.zon`. Colors are `0xRRGGBB` (border) or `0xRRGGBBAA` (bar).

### Layout / Behavior
- `outer_gap=0`, `inner_gap=2`
- `sloppy_focus=true` (focus follows mouse)
- `nmaster=1`, `mfact=0.55`
- floating default size `0.6 × 0.65` of the screen; `float_step=40` px
- `repeat_rate=50`, `repeat_delay=300`
- Border (tmux-style, only on the focused window): `border_active=0x89b4fa` (blue), `border_thickness=2`

### Monitor Layout
Array **order** defines monitor numbering for `focusmon`/`tagmon` and the `.monitor` index in window rules.

| Idx | Name  | Resolution | Position       | Transform   | Notes               |
|-----|-------|-----------|----------------|-------------|---------------------|
| 0   | DP-3  | 3440x1440 | x=0, y=0       | rotate_180  | Primary ultrawide   |
| 1   | DP-2  | 3440x1440 | x=0, y=1440    | normal      | Secondary ultrawide |
| 2   | DP-1  | 1920x1080 | x=3440, y=1440 | rotate_270  | Vertical, 165 Hz    |
| 3   | eDP-1 | 1920x1200 | —              | normal      | Laptop screen       |

### Environment Variables (set by reach)
From the `.env` block in `config.zon`:
- `XDG_CURRENT_DESKTOP=river`
- `XDG_SESSION_TYPE=wayland`
- `QT_QPA_PLATFORM=wayland`
- `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus`

### Autostart (`de/.config/reach/autostart.sh`)
`config.zon`'s `.autostart` just execs `$HOME/.config/reach/autostart.sh`. The script is now **minimal** — most daemons moved to runit user services (see [Services](#services)). It:
- pins `DBUS_SESSION_BUS_ADDRESS` to `$XDG_RUNTIME_DIR/bus`
- starts `runsvdir $HOME/.local/sv` (the per-user runit supervisor) if not already running, and waits for the bus socket
- runs `redshift.sh 4000` (after a 2 s delay), launches `kitty --class rmpc rmpc`
- `dconf load /org/gnome/desktop/interface/ < ~/.config/dconf/interface.dconf` (pushes GTK theme/icons/cursor/font into GNOME settings)

### Window Rules
Match `app_id`/`title`: `^foo` = starts-with, `foo` = contains. `tags` is a `1<<n` bitmask; `monitor` is an index into the monitor array.

| Match        | tags (bitmask) | Float | Monitor | Notes                          |
|--------------|----------------|-------|---------|--------------------------------|
| rmpc         | —              | No    | 2 (DP-1)| Music player on vertical mon   |
| zen          | 4              | No    | —       | switchtotag                    |
| mpv          | 1              | No    | —       | switchtotag                    |
| ^steam       | 16             | No    | —       | —                              |
| ^float       | —              | Yes   | —       | Float at 25%/25%, 50%×50%      |
| pavucontrol  | —              | Yes   | —       | Float at 25%/25%, 50%×50%      |

### Status Bar (baked-in)
reach renders the bar in-process (no dwlb/someblocks). From the `.bar` block:
- Font `JetBrainsMono Nerd Font:size=15`, anchored top, layout symbol `[]=`, delimiter `|`
- Selected tag bg `0xcba6f7` (mauve) / fg white; normal/status fg `0x7f849c`, bg `0x1e1e2e`
- Blocks (someblocks-style: `icon ++ first line of command stdout`; re-run every `interval` s and/or on `SIGRTMIN+signal`):

| Block   | Command                                         | Interval | Signal |
|---------|-------------------------------------------------|----------|--------|
| ip      | `blocks/ip.sh` (default-route iface + IP)       | 30s      | —      |
| audio   | `blocks/audio.sh` (default sink description)     | 60s      | RTMIN+1 |
| volume  | `pactl get-sink-volume @DEFAULT_SINK@` %        | 1s       | RTMIN+1 |
| mic     | `blocks/mic.sh` (source vol, red if unmuted)    | 1s       | RTMIN+2 |
| date    | `date '+%a %m/%d %I:%M %p'`                      | 1s       | —      |
| battery | `blocks/battery.sh` (BAT0 capacity + glyph)     | 30s      | —      |

Keybinds poke the bar with `kill -35 $(pidof reach)` (RTMIN+1, audio/volume) and `kill -36` (RTMIN+2, mic) for instant refresh after a volume change.

### Keybindings
`Super` = Mod. Providing a `.binds` block **replaces the entire default action/spawn/chord keymap** — except the per-tag digit binds (view/toggleview/tag/toggletag for `1`–`9`, the usual dwl scheme) which are always auto-generated and are not listed in the config.

**Launchers & apps:**
| Binding        | Action                                       |
|----------------|----------------------------------------------|
| Super+P        | Lock screen (`swaylock`)                      |
| Super+Tab      | kitty terminal                                |
| Super+Space    | rofi drun (`-show drun -show-icons`)          |
| Super+BackSpace| Floating kitty (`--class float`)              |
| Super+V        | Floating kitty → `clipfzf` (clipboard picker) |
| Super+X        | Floating kitty → `killfzf` (process killer)   |
| Super+Z        | Floating kitty → `svfzf` (user service manager) |
| Super+W        | rmpc (music)                                  |
| Super+Shift+W  | `rmpc rescan`                                 |
| Super+T        | Zen browser (`zen-browser`)                   |
| Super+Shift+B  | Browse `~/Pictures/bgs` with yazi             |
| Super+B        | Random wallpaper (`awww img`, top transition) |
| Super+D        | emacsclient frame (`emacsclient -c`)          |
| Super+E        | eww widgets open (`eww.sh open`) — see note   |
| Super+Shift+E  | eww widgets close (`eww.sh close`) — see note |
| Super+Shift+P  | Quit reach                                    |
| Super+Shift+Q  | Kill focused client                           |
| Super+Return   | Zoom (swap master/stack)                      |
| Super+F        | Toggle floating                               |
| Super+Shift+F  | Toggle fullscreen                             |

> **Note:** `Super+E`/`Super+Shift+E` spawn `~/.local/bin/eww.sh`, but **that script no longer exists in the repo** — eww is now a runit user service that opens the dashboard itself (see [EWW](#eww-desktop-widgets)). These two binds are effectively broken until rebound or `eww.sh` is restored.

**Two-key chords (Super+r then…):**
| Chord       | Action          |
|-------------|-----------------|
| Super+r, d  | Legcord         |
| Super+r, b  | Brave           |
| Super+r, a  | pavucontrol     |
| Super+r, s  | Steam           |

**Screenshots (Super+s then…):**
| Chord       | Action                          |
|-------------|--------------------------------|
| Super+s, s  | Quick screenshot → clipboard   |
| Super+s, d  | Section screenshot + satty     |
| Super+s, 1  | Full DP-1 screenshot           |
| Super+s, 2  | Full DP-2 screenshot           |
| Super+s, 3  | Full DP-3 screenshot           |

**Media / volume / mic / brightness:**
| Binding         | Action                                          |
|-----------------|-------------------------------------------------|
| XF86AudioPlay   | `playerctl -p mpd play-pause`                   |
| XF86AudioPrev   | `playerctl -p mpd previous`                     |
| XF86AudioNext   | `playerctl -p mpd next`                         |
| Alt+Up / Down   | Sink volume ±5% (refresh bar)                   |
| Alt+Left / Right| Mic (source) volume ∓5% / ±5% (refresh bar)     |
| Alt+End         | Mic mute toggle                                 |
| Alt+[ (bracketleft) | Cycle EQ output sink (`flip.sh`)            |
| Super+Alt+Left / Right | Brightness down/up (`brightness.sh`)     |
| Super+Alt+Up    | Toggle night-light 4000K↔6500K (`redshift.sh`)  |

**Focus & layout:**
| Binding                | Action                          |
|------------------------|---------------------------------|
| Super+J / K            | Focus next/prev in stack        |
| Super+H / L            | Resize master area (mfact ∓0.05)|
| Super+M / N            | Decrease/increase nmaster       |
| Super+, / .            | Focus prev/next monitor         |
| Super+Shift+, / .      | Move window to prev/next monitor|
| Super+Arrows           | Move floating window (±40)      |
| Super+Shift+Arrows     | Resize floating window (±40)    |

**Tags (auto-generated defaults):**
| Binding         | Action                |
|-----------------|-----------------------|
| Super+1–9       | View tag              |
| Super+Ctrl+1–9  | Toggle tag visibility |
| Super+Shift+1–9 | Move window to tag    |

---

## Shell (ZSH)

**Config:** `de/.config/zsh/.zshrc`
**Env:** `de/.config/zsh/.zshenv`

### Plugins (zplug)
- zsh-syntax-highlighting
- zsh-autosuggestions
- fzf-tab
- spaceship-prompt
- zsh-vi-mode

### Key Aliases / Functions

| Alias / fn | Command                                   |
|------------|-------------------------------------------|
| gs         | git status -s                             |
| gac        | git add . ; git commit -m                 |
| gp         | git push                                  |
| ip         | ip -c                                     |
| vim        | nvim                                      |
| ff         | fastfetch                                 |
| y          | yazi (function; cd's to last dir on exit) |
| ta         | tmux attach-session -t                    |
| pickcolor  | grim+slurp+convert color picker           |
| zshrc      | nvim $ZDOTDIR/.zshrc                       |
| pyserver   | python -m http.server                     |
| doomsync   | pkill emacs → `sv stop emacs` → doom sync → `sv start emacs` |
| xi/xr/xu/xq| **stale Void xbps wrappers** — see [Stale leftovers](#stale-voiddwl-leftovers) |

### FZF Integration
- Default: `fd --hidden --strip-cwd-prefix --exclude .git`
- Ctrl+T: find files, Ctrl+R: history, Alt+C: cd into directory

### History
- 1M entries, ignores duplicates, excludes: ls, cd, pwd, exit

### XDG Paths (from .zshenv)
- CONFIG: ~/.config, DATA: ~/.local/share, STATE: ~/.local/state, CACHE: ~/.cache
- ZDOTDIR: ~/.config/zsh
- All tool homes (cargo, rustup, go, npm, yarn, etc.) redirect to XDG_DATA_HOME
- `EDITOR=nvim`

---

## Terminal: kitty

**Config:** `de/.config/kitty/kitty.conf`
- Font: JetBrainsMono Nerd Font, size 12.0
- Scrollback: 1,000,000 lines
- Cursor trail: enabled
- Audio bell: disabled
- Window decorations: hidden
- Clipboard: Ctrl+Shift+C/V
- Theme: Catppuccin Mocha (current-theme.conf)
- Sync to monitor: yes
- Window classes used by reach binds: `float` (floating fzf pickers), `rmpc` (music player)

---

## Tmux

**Config:** `de/.config/tmux/tmux.conf`
- Prefix: `Ctrl+F`
- Base index: 1 (windows and panes)
- Terminal: tmux-256color with true colors
- Shell: /bin/zsh
- Mouse: enabled
- Renumber windows: on

### Keybindings

| Key     | Action             |
|---------|--------------------|
| r       | Reload config      |
| h/j/k/l | Select pane        |
| X       | Kill session       |

### Plugins (tpm)
- catppuccin/tmux — theme
- tmux-sensible — sensible defaults
- tmux-resurrect — session persistence
- tmux-continuum — auto-save every 5 minutes

---

## Neovim

**Config:** `de/.config/nvim/`
Plugin manager: lazy.nvim (auto-installed to ~/.local/share/lazy/lazy.nvim)

### Core Settings (keymaps.lua)
- Leader: `Space`, Local leader: `Space`
- Line numbers: absolute + relative
- True colors, cursor line highlight, auto-read
- Clipboard: unnamed plus (system clipboard)
- Indentation: tab=4, shift=4, expandtab
- Netrw: disabled (uses nvim-tree)

### Keybindings

| Binding       | Action                                |
|---------------|---------------------------------------|
| `<leader>k`  | Float diagnostics                     |
| `gx`          | Open file/URL under cursor           |
| `<leader>e`  | Toggle nvim-tree                      |
| `<leader><tab>` | Switch between file and tree        |
| `<leader>ff` | Telescope: find files                 |
| `<leader>fg` | Telescope: live grep                  |
| `<leader>fb` | Telescope: buffers                    |
| `<leader>fh` | Telescope: help tags                  |
| `<leader>sc` | Spell: correct word (first suggestion)|
| Tab / Shift+Tab | cmp: next/prev completion item      |
| Ctrl+Space   | cmp: trigger completion               |
| CR            | cmp: confirm selection               |

### Plugins

| Plugin          | Purpose                          |
|-----------------|----------------------------------|
| catppuccin      | Colorscheme (mocha, priority 1000) |
| lualine         | Statusline (catppuccin theme)    |
| nvim-tree       | File tree (right side, width 35) |
| telescope       | Fuzzy finder                     |
| treesitter      | Syntax/indentation               |
| nvim-lspconfig  | LSP                              |
| mason           | LSP package manager (lua_ls, pyright) |
| nvim-cmp        | Completion (LSP + snippets + buffer + path) |
| LuaSnip         | Snippet engine + friendly-snippets |
| colorizer       | Color code highlighting          |
| image.nvim      | Image display (kitty backend)    |
| markview        | Markdown preview                 |
| neoformat       | Code formatting                  |
| vim-be-good     | Vim practice game                |
| miss.nvim       | Vim motions practice             |

### Spell checking
- Enabled for markdown and text files
- Language: en_us

---

## Doom Emacs

**Config:** `de/.config/doom/`
- Font: JetBrainsMono Nerd Font 20
- Theme: catppuccin
- Line numbers: enabled
- Org directory: ~/org/
- `select-enable-primary` + `select-enable-clipboard` both `t` (sync PRIMARY and clipboard)
- `markdown-max-image-size = (1600 . 1200)` (max inline image w×h in px)

### Enabled Modules
- Completion: corfu (+orderless), vertico
- UI: doom, doom-dashboard, hl-todo, modeline, ophints, popup, treemacs, vc-gutter, workspaces
- Editor: evil (vim bindings), file-templates, fold, snippets
- Emacs: dired, electric, undo, vc
- Terminal: vterm
- Checkers: syntax
- Tools: eval, lookup, magit, tree-sitter
- Languages: emacs-lisp, latex, lua, markdown, org, sh
- Default: +bindings, +smartparens

### Custom keybinds (config.el)
- treemacs (evil): `H` → `treemacs-root-up`, `L` → `treemacs-root-down`

### Packages (packages.el)
- catppuccin-theme

### Daemon
- Runs as a runit **user service** (`~/.local/sv/emacs`); `doomsync` restarts it via `sv`
- `Super+D` in reach opens a client frame (`emacsclient -c`)
- `doomsync` alias: kill → `sv stop emacs` → doom sync → `sv start emacs`

---

## EWW Desktop Widgets

**Config:** `de/.config/eww/`
**Architecture:** Single config dir (the old `dash/` subdir is gone; `de/.config/eww.bak/` still holds the old layout as a backup):
- `eww.yuck` — all widget + window definitions
- `eww.scss` — styling; does `@import "scale"` → reads the generated `_scale.scss`
- `_scale.scss` — generated at runtime (holds `$scale`); sits next to `eww.scss`
- `scripts/` — data provider scripts
- `calendar.url` — ICS/CalDAV URL for calendar widget

### Launch (runit service)
The eww **daemon and dashboard now live in the `eww` runit user service** (`~/.local/sv/eww/run`) — there is no `eww.sh` anymore. The service:
- waits for the dbus + wayland sockets, exports `WAYLAND_DISPLAY`
- detects monitor/scale (if `DP-2` present → monitor 1 desktop, scale `1.0`; else monitor 0 laptop, scale `0.85`)
- writes `_scale.scss`, reloads SCSS, then opens every window once with `--screen <mon> --arg scale=<scale>`
- `exec`s `eww daemon --no-daemonize` so runsv supervises the long-lived daemon (not the one-shot open, which would flap)

`scale` drives **both** CSS sizes (`eww.scss` `s(n)` helper → `n*$scale*1px`, fed by `_scale.scss`) and window geometry (a per-window `scale` arg, since `defwindow :geometry` can't read globals).

### EWW Styling
`eww.scss` uses the Catppuccin Mocha palette with `$border-radius: 0px` — all widgets are flat/sharp.

### Widgets (de/.config/eww/eww.yuck)
Eleven windows are launched: `clock cpu net-graph tray weather notifications mpd outlook ports vpn brightness`.

| Window        | Data Source                              | Interval    | Notes                                                    |
|---------------|------------------------------------------|-------------|---------------------------------------------------------|
| clock         | `date`                                   | 1s/60s      | Time + date                                             |
| cpu           | EWW_CPU/EWW_RAM/EWW_DISK + nvidia-smi + /sys/class/thermal | built-in/2s | Overlaid CPU/RAM/disk graphs + GPU usage + CPU/GPU temps |
| net-graph     | /proc/net/dev (eth/en/wl) + `ip -j addr` + jq | 1s/10s | Up/down MB/s + IP list (incl. tun/tap/wg)               |
| tray          | systray (built-in)                       | —           | System tray icons                                       |
| weather       | wttr.in (curl)                           | 600s        | Temp, condition, humidity, wind                         |
| notifications | makoctl history -j + jq                  | 2s          | Recent notifs, DND mode toggle + dismiss-all            |
| mpd           | mpc + wpctl                              | 1s / 0.5s   | Cover, controls, progress + **volume sliders** (speaker/mic) |
| ports         | scripts/ports.sh (ss + jq)               | 5s          | Listening TCP ports                                     |
| outlook       | scripts/calendar.sh events (icalendar)   | 60s         | ICS calendar, next 7 days, refresh button               |
| vpn           | scripts/vpn-manager.sh list/status       | 5s / 2s     | OpenVPN connect/toggle                                  |
| brightness    | `~/.local/bin/brightness.sh get/set`     | 2s          | Software brightness slider (10–100%) for ALL outputs via wl-gammarelay-rs |

> **Note:** The volume sliders are not a standalone window — the `(volume)` widget is embedded inside the `mpd` widget.

### EWW Scripts (de/.config/eww/scripts/)
- `ports.sh` — ss + awk + jq → JSON array of {proto, port, process}
- `calendar.sh` — Python (`events`, `refresh` subcommands): requires `icalendar` + `recurring_ical_events` (installed via home-manager); reads ~/.config/eww/calendar.url; caches ICS to /tmp/eww-calendar.ics
- `vpn-manager.sh` — OpenVPN management (`list`, `status`, `toggle`); state in /tmp/eww-openvpn.{pid,status,log}
- `focused-output.sh` — wlr-randr monitor detection

### EWW Dependencies
- jq — ports, notifications, net-graph (IP list)
- wl-gammarelay-rs + gdbus — brightness widget (software gamma dimming over the D-Bus session bus)
- mpc — mpd widget; wpctl — volume sliders (in mpd window)
- makoctl — notifications widget (history -j, mode toggle, dismiss)
- nvidia-smi — GPU usage + temp in the cpu widget
- curl — weather (wttr.in)
- python3 + `icalendar` + `recurring-ical-events` — calendar widget (managed by home-manager)
- wlr-randr — monitor detection (in the eww service)
- Calendar URL config: `~/.config/eww/calendar.url` (ICS/CalDAV URL)

---

## Notification Daemon: mako

**Config:** `de/.config/mako/config`

Replaced dunst. mako is Wayland-native and `makoctl` talks D-Bus directly (via basu), so it needs no `busctl`/systemd. mako just needs the D-Bus **session bus** reach provides (pinned via `DBUS_SESSION_BUS_ADDRESS`); it runs as a runit user service (`~/.local/sv/mako`) and inherits the bus like every other service. (Running `mako`/`makoctl`/`notify-send` from a terminal that lacks that env — e.g. one that survived a session restart — fails with "Could not connect"; open a fresh terminal under the session.)

- Font: JetBrains Mono Nerd Font 18
- Anchor: top-right, border-size 2, **border-radius 0** (flat), width 350
- Background #1e1e2e, text #cdd6f4, border #cba6f7 (mauve)
- Urgency low: border #45475a; normal: border #cba6f7; critical: border #fab387 (peach), no timeout
- `max-history=20` (ring buffer — mako has **no "clear history"** command; the eww clear button maps to `makoctl dismiss -a`, which only clears on-screen popups)
- DND is a **mode**: `[mode=do-not-disturb]` with `invisible=1`, toggled by the eww bell button via `makoctl mode -t do-not-disturb`
- `notify-send` requires the `libnotify` package

---

## Application Launcher: rofi

**Config:** `de/.config/rofi/config.rasi`
- Theme: `~/.local/share/rofi/themes/spotlight-dark.rasi`
- Wayland version (rofi-wayland)

---

## File Manager: yazi

**Config:** `de/.config/yazi/`

### Settings
- Pane ratio: 2/5/8 (sidebar/main/preview)
- Sort: alphabetical, case-insensitive, dirs first
- Show hidden: yes
- Mouse: click + scroll
- Image cache: /tmp/yaziimgcache

### Openers

| Type    | Opener          |
|---------|----------------|
| edit    | nvim ($EDITOR) |
| open    | xdg-open       |
| setbg   | `swww img` (stale — system uses `awww`) |
| view    | loupe          |
| read    | zathura (PDF)  |
| play    | mpv            |
| extract | ya pub extract |

### Plugins
- git — file status
- piper — markdown/flac preview
- mount — disk mounting
- chmod — permissions

### Key Highlights

| Key     | Action              |
|---------|---------------------|
| h/j/k/l | Navigate (vim)     |
| /       | Search next         |
| ?       | Search previous     |
| S       | Ripgrep search      |
| Z       | Zoxide jump         |
| z       | FZF jump            |
| M       | Mount (plugin)      |
| c+m     | Chmod (plugin)      |
| .       | Toggle hidden       |

---

## Music: MPD + rmpc

### MPD Config (`de/.config/mpd/mpd.conf`)
- Port: 6600
- Music: ~/Music, Playlists: ~/Music/playlists
- Audio output: PipeWire (pulse backend), software mixer
- Format: 192kHz, 24-bit, stereo
- Curl input: enabled (streaming)
- Runs as a runit user service (`~/.local/sv/mpd`)

### mpDris (`de/.config/mpd/mpDris.conf`)
- Server: 127.0.0.1:6600 (runit user service `mpDris2`)

### rmpc (`de/.config/rmpc/config.ron`)
- Connection: 127.0.0.1:6600
- Theme: "miles" (custom)
- Volume step: 5%, Max FPS: 165, scrolloff: 3
- Album art: auto-detect, max 1200x1200, no HTTP sources
- Directory sort: modified time (reverse)
- Tabs: Queue, Directories, Playlists, Lyrics, Search
- Vim-style navigation (hjkl, gg/G, Ctrl+hjkl for panes)

---

## Screen Lock: swaylock

**Config:** `de/.config/swaylock/config`
- Background: #000000
- Ring default: #6c7086, clear: #89b4fa, verifying: #a6e3a1, wrong: #f38ba8
- Inside default: #313244
- Key highlight: #cba6f7 (mauve), backspace: #f38ba8
- Text: #cdd6f4
- Ignore empty password: enabled
- Triggered by `Super+P` and by the `swayidle` user service (idle timeout)

---

## System Monitor: btop

**Config:** `de/.config/btop/btop.conf`
- Theme: mocha.theme (Catppuccin)
- Color: 24-bit truecolor
- Graph: braille symbols
- Boxes: cpu, mem, net, proc
- Update rate: 400ms
- Process sort: Memory
- Temperature: Celsius
- GPU: Nvidia, AMD, Intel

---

## System Info: fastfetch

**Config:** `de/.config/fastfetch/config.jsonc`

Logo: `source: auto`. Module order: Title, Separator, Host, CPU, GPU, Memory, Swap, Disk, Display, OS, Kernel, Bootloader, Init, Driver (custom — nvidia/OpenGL/OpenCL/Vulkan versions), OS Age (custom — from `/` birth time), Seat Manager (custom), Packages, WM, Login Manager (custom), Theme, Icons, Font, Cursor, Terminal, Shell.

> **Stale (Void):** the **Seat Manager** and **Login Manager** custom `command` modules still call `xbps-query` and scan runit's `/var/service/`. On this Gentoo box `xbps-query` doesn't exist and the runit service dir is `/service`, so these two entries are broken until rewritten for Portage (`equery`/`qlist`) + `/service`.

---

## GTK / Qt Theming

**UI Aesthetic: flat/sharp** — all border-radius is 0 across GTK and eww. Enforced globally in `gtk-3.0/gtk.css` (sets `border-radius: 0px` on `*`, `window`, `button`, `entry`, `.titlebar`).

### GTK3 (`de/.config/gtk-3.0/`)
**Stowed directly** as plain files (no longer home-manager–generated). Edit the repo files and re-stow. Settings are also pushed into GNOME's dconf via `dconf load` (`de/.config/dconf/interface.dconf`) in reach autostart.
- Theme: `catppuccin-mocha-mauve-standard+default`
- Icons: **Papirus-Dark**
- Font: JetBrainsMono Nerd Font 14
- Cursor: Bibata-Modern-Classic, size 24
- `gtk-application-prefer-dark-theme = 0`
- `gtk.css` (border-radius override) also lives at `de/.config/gtk-3.0/gtk.css`

### GTK4 (`de/.config/gtk-4.0/`)
Also stowed directly. Contains `settings.ini`, `gtk.css`, `gtk-dark.css`, and `assets/`.

### dconf (`de/.config/dconf/interface.dconf`)
Loaded into `/org/gnome/desktop/interface/` by reach autostart so GTK apps that read GNOME settings get: gtk-theme, icon-theme, cursor-theme/size, font-name, `color-scheme='prefer-dark'`.

### xsettingsd (`de/.config/xsettingsd/xsettingsd.conf`)
XSETTINGS daemon for non-GTK/Qt apps (Firefox, Signal, Electron). Must be running for these apps to pick up dark theme + cursor.
- `Net/ThemeName` — catppuccin-mocha-mauve-standard+default
- `Net/IconThemeName` — Papirus-Dark
- `Gtk/CursorThemeName` — Bibata-Modern-Classic
- `Gtk/ApplicationPreferDarkTheme 1` — required for Firefox/Signal dark mode
- `Xft/Antialias 1`, `Xft/Hinting 1` (hintslight), `Xft/RGBA rgb`

### Qt6 (`de/.config/qt6ct/qt6ct.conf`)
- Style: Kvantum
- Color: catppuccin-mocha-mauve
- Font: JetBrainsMono Nerd Font 13
- Single-click activation: yes

> reach sets `QT_QPA_PLATFORM=wayland` (native Wayland Qt). It does **not** set `QT_QPA_PLATFORMTHEME`/`QT_STYLE_OVERRIDE` like the old dwl setupenv did — if Qt apps stop picking up qt6ct/Kvantum, re-export those.

### Kvantum (`de/.config/Kvantum/kvantum.kvconfig`)
- Theme: catppuccin-mocha-mauve

---

## Audio: PipeWire + WirePlumber

### PipeWire (`de/.config/pipewire/`)
- `pipewire.conf` — custom config based on PipeWire defaults
- `pipewire.conf.d/` — drop-in config fragments:
  - `custom.conf` — `default.clock.rate = 192000`, `allowed-rates = [ 192000 ]`, `link.max-buffers = 16`
  - `sink-eq.conf` — 16-band parametric EQ via PipeWire's builtin `filter-chain` module (replaces EasyEffects). Creates two EQ sinks, each pinned via `target.object` to a specific hardware output:
    - `effect_input.eq_fiio` → FiiO K11 USB DAC
    - `effect_input.eq_optical` → USB2.0 optical device
    - All bands: type `bq_peaking` (Bell), Q=2.3521, mode APO(DR); coefficients mirror the old `easyeffects/output/EQ.json`. L/R share identical controls. **Keep both instances' coefficients in sync if regenerating the curve.**
    - Verify after restart: `wpctl status | grep -E "effect_input\.eq_(fiio|optical)"`

### EQ output switching
Apps connect to the default sink; `~/.local/bin/flip.sh` (bound to `Alt+[`) cycles the default between the two `effect_input.eq_*` sinks so the stream passes through the EQ pinned to that hardware output. Raw `alsa_output.*` sinks are excluded (pick those via wpctl/pavucontrol to bypass EQ).

### WirePlumber (`de/.config/wireplumber/wireplumber.conf.d/`)
- `softvol.conf` — ALSA rule: enables `api.alsa.soft-mixer = true` for all USB audio cards (`alsa_card.usb-.*`). Required for USB audio devices to have software volume control.
- `usb2-iec958.conf` — profile rule for the USB2.0 optical device (its comment still references the old `~/.local/src/dwl/autostart.sh` — now driven by `flip.sh`).

PipeWire/WirePlumber/pipewire-pulse run as runit user services.

---

## Zen Browser

### Chrome (`de/.zen/chrome/userChrome.css`)
- Catppuccin Mocha Mauve dark theme
- Primary: #313244, Accent: #cba6f7, BG: #1e1e2e, Text: #cdd6f4
- Custom tab/sidebar appearance, removes outer padding

### user.js (`de/.zen/user.js`)
- Custom CSS: enabled (toolkit.legacyUserProfileCustomizations.stylesheets=true)
- Content element separation: 0

### mimeapps.list (`de/.config/mimeapps.list`)
- Default browser: zen.desktop
- Discord: legcord.desktop
- PDF/images/HTML/HTTP/HTTPS: zen.desktop

---

## Screencast Portal

**Config:** `de/.config/xdg-desktop-portal-wlr/config`
- Chooser: simple (slurp for region selection)
- Command: `slurp -f %o -or`

---

## Custom Scripts (`de/.local/bin/`)

### screenshot.sh
- `ss` — quick screenshot to clipboard (grim+slurp)
- `section` — region screenshot → satty annotation
- `DP-1/2/3/HDMI-1/2` — full monitor → satty annotation
- Output: ~/Pictures/screenshot-YYYY-MM-DD_HH-MM-SS.png

### flip.sh
Cycles the default sink between the two EQ filter-chain sinks (`effect_input.eq_fiio` / `effect_input.eq_optical`) and migrates already-playing app streams to the new default. When switching to the optical EQ, first sets the USB2.0 card to its `iec958-stereo` profile so the chain's `target.object` resolves. Raw `alsa_output.*` sinks are intentionally excluded. Uses pactl. Bound to `Alt+[`.

### redshift.sh
Night-light color temperature for **all** outputs via `wl-gammarelay-rs` (D-Bus session bus, `gdbus`). `redshift.sh` toggles 4000K↔6500K (Mod+Alt+Up); `redshift.sh <K>` sets an absolute Kelvin. Replaces the old `gammastep.sh`.

### brightness.sh
Software brightness for **all** outputs (laptop panel + the 3 externals) via `wl-gammarelay-rs` — dims the gamma curve per output, so it works on DP/HDMI monitors with no `/sys/class/backlight`. Uses the D-Bus **session** bus reach provides (via `gdbus`); no root/i2c. Subcommands: `up`/`down` (±5%), `set <0-100>` (eww slider), `get` (eww poll). Floor 10% (never fully black). Bound to Super+Alt+Left/Right and drives the eww `brightness` widget.

### clipfzf
Clipboard-history picker: `cliphist list | fzf | cliphist decode | wl-copy`. Bound to `Super+V` (floating kitty via `float` class). Output redirected so kitty exits once copied.

### killfzf
Process killer: `ps --forest` tree → fzf (kernel threads under PID 2 filtered out). `Enter` = SIGTERM, `Ctrl-K` = SIGKILL, `Tab` = multi-select. Bound to `Super+X`.

### svfzf / ssvfzf
Two runit service managers (floating kitty, fzf). Both share the same UI — glyphs `●` running / `○` enabled but stopped / `·` disabled; keys `enter` toggle running, `ctrl-e` enable + start, `ctrl-d` disable + stop, `ctrl-r` restart, `tab` multi-select, `esc` quit; the list re-renders after each action. Originally one merged script — **split in two** because per-call `doas` prompts were wonky inside the fzf action loop (stdin is the pick pipeline, so `doas` couldn't read a password).

- **`svfzf`** — **user** services in `~/.local/sv`, supervised by the per-user `runsvdir ~/.local/sv` from reach autostart. No elevation; all `sv` calls run with `SVDIR=~/.local/sv`. The dir **is** the supervised set (no symlink layer), so enable/disable = `rm`/`touch` a `down` file inside the service dir. Bound to `Super+Z`.
- **`ssvfzf`** — **system** services in `/etc/sv`, supervised via `/service` symlinks. Elevates **once** up front by re-exec'ing under `doas` (this box symlinks `sudo`→`doas`), so root persists for the whole session and nothing in the loop re-prompts; the fzf UI runs as root. Enable/disable = add/remove the `/service` symlink. No default keybind (run from a terminal).

### rebuild-kernel.sh
Gentoo kernel rebuild helper (this box is "lazygentoo" with Secure Boot + UKI). Optionally `emerge --update`s `sys-kernel/gentoo-sources` (`-e`), seeds `.config` (from `-c FILE`, the running `/proc/config.gz`, or the existing `$SRC/.config`), `olddefconfig`s, builds + installs modules, then `kernel-install add` builds the initramfs+UKI, signs it (ukify, keys from `/etc/kernel/uki.conf`), prunes old UKIs, and rewrites the efibootmgr entry — all via `/etc/kernel/install.d` hooks. Self-elevates via `doas` (this box symlinks `sudo`→`doas`). `-y` skips the prompt; `-h` for usage.

### runbar.sh — **stale**
`pkill dwlb; dwlb &; someblocks -p | dwlb -status-stdin all`. Dead — reach has a baked-in bar and dwlb/someblocks are gone. No longer bound to anything.

---

## Services

Both scopes are **runit**, managed by separate pickers: `svfzf` (user, `Super+Z`) and `ssvfzf` (system, elevates via `doas`) — or `sv` directly. See [svfzf / ssvfzf](#svfzf--ssvfzf).

### User Services (runit, `~/.local/sv`)
Supervised by a per-user `runsvdir ~/.local/sv` started from reach `autostart.sh`. Disable a service by dropping a `down` file in its dir (no symlink layer). Manage with `svfzf` or `SVDIR=~/.local/sv sv <cmd> <name>`. Current set:
- `dbus` — persistent user D-Bus **session** bus (pinned via `DBUS_SESSION_BUS_ADDRESS`; the whole stack inherits it)
- `pipewire`, `pipewire-pulse`, `wireplumber` — audio
- `mpd` — Music Player Daemon
- `mpDris2` — MPRIS interface for MPD
- `emacs` — Doom Emacs daemon
- `eww` — eww daemon + opens the dashboard (replaces the old `eww.sh` + autostart launch)
- `mako` — notification daemon
- `awww` — wallpaper daemon
- `syncthing`
- `wl-gammarelay-rs` — gamma/brightness D-Bus service (drives brightness.sh + redshift.sh + eww widget)
- `swayidle` — idle locker (`swayidle -w timeout 300 'swaylock -f'`)
- `cliphist-text` / `cliphist-image` — clipboard-history watchers (`wl-paste --type {text,image} --watch cliphist store`); one service per type

### System Services (runit, `/etc/sv` → `/service`)
Enable/disable via the `/service` symlink (managed by `ssvfzf`, or `ln`/`rm` + `sv`). These live **outside this repo** (system-level, not stowed), so the exact set isn't tracked here — inspect `/etc/sv` and `/service` on the box. Typically: a display manager (greetd/tuigreet), `ufw`, `bluetooth`, `dbus`, `udisks2`.

---

## Package Management

**Primary: Portage** (Gentoo)
```bash
sudo emerge -av <pkg>              # install (sudo → doas on this box)
sudo emerge --unmerge <pkg>        # remove
emerge --search <pkg>              # search (or `eix <pkg>`)
sudo emerge --sync && sudo emerge -avuDN @world   # update system
```

**Secondary: Nix / home-manager** — security tools, theming packages, Python libs
```bash
home-manager switch          # apply home.nix changes
nix-env -iA nixpkgs.<pkg>    # ad-hoc nix package
nix-collect-garbage -d       # remove old generations + garbage collect
```

**Kernel:** see [`rebuild-kernel.sh`](#rebuild-kernelsh).

---

## Stale Void/DWL leftovers

Tracked here so they can be cleaned up. None are load-bearing on Gentoo + reach:

- `de/.config/zsh/.zshrc` — `xi`/`xr`/`xu`/`xq` aliases wrap `xbps-install`/`xbps-remove`/`xbps-query` (won't work on Portage; repoint to `emerge`/`eix`).
- `de/.config/fastfetch/config.jsonc` — Seat Manager + Login Manager modules call `xbps-query` and scan `/var/service/` (Void runit path; this box uses `/service`).
- `de/.local/bin/runbar.sh` — entirely dwlb/someblocks; dead, unbound.
- `de/.config/yazi/yazi.toml` — `setbg` opener uses `swww img` (system uses `awww`).
- `de/.config/wireplumber/wireplumber.conf.d/usb2-iec958.conf` — comment points to `~/.local/src/dwl/autostart.sh` (now `flip.sh`).
- `~/.local/bin/eww.sh` is referenced by reach's `Super+E`/`Super+Shift+E` binds but **doesn't exist** (eww is a service now) — rebind or restore.
- `de/.config/eww.bak/` — old eww layout backup dir.
- Comments mentioning "dwl"/"Void" in `clipfzf`, `killfzf`, `svfzf`, `brightness.sh`, `~/.local/sv/emacs/run` (cosmetic).

---

## Git Workflow

```bash
gs    # git status -s
gac   # git add . ; git commit -m
gp    # git push
```

---

## .gitignore Exclusions

- `.local/share/tmux/plugins/` — tmux plugins
- UUID files
- `lazy-lock.json` — Neovim lock
- MPD runtime files (log, state, db, pid)
- `*.m3u` — playlist files
- Neovim spell files
