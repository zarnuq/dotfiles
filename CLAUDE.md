# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal dotfiles for a **Void Linux** system. Wayland compositor stack centered on DWL (custom-patched dwm port). GNU Stow manages all symlinks from `de/` to `$HOME`. Terminal emulator is **kitty** (not ghostty, not wezterm). Theme is **Catppuccin Mocha (Mauve accent)** across all applications. UI aesthetic: **flat/sharp** — all border-radius is explicitly 0 everywhere.

Package manager is `xbps` (`xbps-install`, `xbps-query`, `xbps-remove`). `pacman`/`paru`/AUR do not apply. Nix + home-manager is used alongside xbps for a curated set of packages (security tools in `cyber.nix`, GUI apps, Python libs — see [Nix / home-manager](#nix--home-manager) section). Clean nix garbage with `nix-collect-garbage -d`.

---

## Repository Structure

```
dotfiles/
├── de/                        # Stowed to $HOME
│   ├── .config/               # Application configs
│   ├── .local/bin/            # Custom scripts
│   ├── .local/src/            # WM source (dwl, dwlb, someblocks)
│   ├── .local/share/          # Shared data
│   └── .zen/                  # Zen browser chrome/userChrome.css
├── archive/                   # Archived old configs
└── screenshots/               # README screenshots
```

---

## Installation & Setup

```bash
cd ~
git clone https://github.com/zarnuq/dotfiles.git
cd dotfiles
stow de
~/.local/bin/install.sh
```

### install.sh functions
- `install_groups()` — adds user to: power, video, storage, kvm, disk, audio, nordvpn, mpd
- `install_system()` — enables pacman colors + multilib (Arch-era; Void equivalent: xbps config)
- `install_packages()` — base, dev, terminal, wayland, audio, media, fonts, libraries
- `install_paru()` — AUR helper (Arch-era; not applicable on Void)
- `install_aur()` — AUR packages (Arch-era; not applicable on Void)
- `install_dwl()` — builds and installs dwl, dwlb, someblocks (binaries symlinked to /bin/)
- `install_grub()` — GRUB with Catppuccin Mocha theme
- `install_greetd()` — tuigreet display manager
- `install_swap()` — 16GB swapfile
- `install_shell()` — zsh + zplug, sets shell to /bin/zsh
- `install_zen()` — symlinks Zen browser configs
- `install_tpm()` — tmux plugin manager
- `install_services()` — enables: mpd, mpdris, xdg-desktop-portal, ufw, udisks2, bluetooth, dbus, greetd
- `install_nvidia()` — installs Nvidia packages (opt-in, available via install-tui.sh)

### install-tui.sh
Interactive fzf-based TUI that wraps `install.sh`. Presents a multi-select menu of all install modules using Catppuccin Mocha colors. Use tab to toggle modules, Enter to run selected ones. Includes `nvidia` as a selectable option (not run by default).

### Stow Commands
```bash
stow de      # apply all symlinks
stow -D de   # remove all symlinks
```

### Building Window Managers
```bash
cd ~/.local/src/dwl && make clean install
cd ~/.local/src/dwlb && make clean install
cd ~/.local/src/someblocks && make
```

---

## Nix / home-manager

**Configs:**
- `de/.config/home-manager/home.nix` — main config (GUI apps, Python ecosystem); imports `cyber.nix`
- `de/.config/home-manager/cyber.nix` — security / pentesting toolkit (`home.packages`)
- `de/.config/home-manager/flake.nix` / `flake.lock` — flake pinning inputs
- `de/.config/nixpkgs/config.nix` — `{ allowUnfree = true; }` (required for burpsuite, wpscan, binaryninja-free, etc.)

Home-manager is used **alongside** xbps on Void Linux to manage a curated set of packages that aren't easily available or kept up-to-date via xbps. Run `home-manager switch` to apply.

> **Note:** `home.nix` is now intentionally minimal — it no longer manages GTK theming (`gtk.enable`), cursors, fonts, the Tidaler `.desktop` entry, or Qt/Kvantum plugins. GTK theming is now stowed directly (see [GTK / Qt Theming](#gtk--qt-theming)). EasyEffects was dropped in favor of a PipeWire filter-chain EQ (see [Audio](#audio-pipewire--wireplumber)).

### Session Variables (injected by home-manager)
- `XDG_DATA_DIRS=/usr/local/share:/usr/share:$HOME/.nix-profile/share`

(This is the only session variable home.nix sets now. Qt/theme env vars are set by DWL's setupenv patch — see [DWL Environment Variables](#environment-variables-set-by-dwl-via-setupenv-patch).)

### home.nix Packages (GUI + Python)
- GUI apps: `obsidian`, `antigravity`, `termius`, `legcord`, `steam`, `nwg-look`, `vscodium`
- LaTeX: `texlive.combine { scheme-medium + latexmk }`
- Python: `python3.withPackages` → `impacket`, `virtualenv`, `pip`, `icalendar`, `recurring-ical-events`, `x-wr-timezone` (last three power the eww calendar widget)
- `pipx`

### Security / Pentesting Toolkit (`cyber.nix`)

A separate file imported by `home.nix`, providing `home.packages`. Current list (trimmed from the larger former set — many tools commented out or removed):

| Category              | Tools                                                                                    |
|-----------------------|------------------------------------------------------------------------------------------|
| RECON & OSINT         | enum4linux, theharvester, whois, dnsrecon                                                |
| SCANNING & ENUM       | nmap, onesixtyone, nikto, snmpcheck                                                      |
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

> **Note:** `hashcat` is installed via nix but the comment recommends the system `/usr/bin/hashcat` for OpenCL/GPU driver compatibility.

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
| Blue       | #89b4fa   | Info, links                    |
| Green      | #a6e3a1   | Success                        |
| Peach      | #fab387   | Warnings                       |
| Red        | #f38ba8   | Errors, critical               |
| Teal       | #94e2d5   | Alternate accent               |
| Yellow     | #f9e2af   | Misc highlights                |
| Lavender   | #b4befe   | Soft accent                    |

---

## DWL Window Manager

**Config:** `de/.local/src/dwl/config.h`

### Applied Patches
autostart, warpcursor, cursortheme, customfloat, monitorconfig, ipc, centerfloating, tmuxborder, moveresizekb, switchtotag, regexrules, keepontag, keychords, setupenv

### Monitor Layout

| Name  | Resolution | Position     | Rotation | Notes              |
|-------|-----------|--------------|----------|--------------------|
| eDP-1 | 1920x1200 | —            | normal   | Laptop screen      |
| DP-2  | 3440x1440 | x=0, y=1440  | normal   | Secondary ultrawide |
| DP-3  | 3440x1440 | x=0, y=0     | 180°     | Primary ultrawide  |
| DP-1  | 1920x1080 | x=3440, y=1440 | 270°   | Vertical monitor   |

All: mfact=0.55, nmaster=1, tile layout, scale=1.0

### Environment Variables (set by DWL via setupenv patch)
- `XDG_CURRENT_DESKTOP=sway` (Wayland compatibility)
- `XDG_SESSION_TYPE=wayland`
- `QT_QPA_PLATFORMTHEME=qt6ct`
- `QT_STYLE_OVERRIDE=kvantum`
- `WAYLAND_DISPLAY=wayland-0`
- `JAVA_HOME=/usr/lib/jvm/java-21-openjdk`
- `XDG_DATA_DIRS=/home/miles/.nix-profile/share:/usr/local/share:/usr/share` (propagates nix profile to all DWL children)

### Autostart (`de/.local/src/dwl/autostart.sh`)
The autostart patch's array in `config.h` just execs `$HOME/.local/src/dwl/autostart.sh`. The script first `pkill`s each daemon (clean restart on session reload), then launches them backgrounded under a `trap 'kill 0'`:
- pipewire, pipewire-pulse, wireplumber
- eww daemon (`--config $HOME/.config/eww`) + `~/.local/bin/eww.sh open`
- mpd (`mpd --no-daemon`)
- mpDris2
- wl-clip-persist (`-c regular`)
- mako
- syncthing (`--no-browser`)
- gammastep -O 4000:4000
- awww-daemon (wallpaper daemon)
- dwlb + `someblocks -p | dwlb -status-stdin all`
- kitty --class rmpc rmpc
- emacs --fg-daemon (Emacs daemon; replaces relying solely on the systemd user service)

> **Note:** No more `easyeffects` (EQ moved to PipeWire conf). The wallpaper daemon is `awww`/`awww-daemon` here and in the Mod+B keybind, though `install.sh` still installs `swww` — likely an `awww` fork/rename or a consistent naming choice.

### Window Rules (regex-based)

| App ID      | Tag  | Float | Monitor | Notes                       |
|-------------|------|-------|---------|----------------------------|
| rmpc        | —    | No    | DP-3    | Music player on primary     |
| zen         | 2    | No    | —       | Browser auto-switches tag   |
| mpv         | 0    | No    | —       | Video on tag 0              |
| ^steam      | 4    | No    | —       | Steam on tag 4              |
| ^float      | —    | Yes   | —       | Float at 25%/25%, 50%/50%  |
| pavucontrol | —    | Yes   | —       | Float at 25%/25%, 50%/50%  |

### Layouts
1. `[]=` — Tile (master/stack)
2. `><>` — Floating
3. `[M]` — Monocle

### Keyboard Settings
- Cursor theme: Bibata-Modern-Classic (size 24)
- Sloppyfocus: enabled (focus follows mouse)
- Border: 1px, focus color: #cba6f7, urgent: #ff0000
- Repeat rate: 50Hz, delay: 300ms

### Keybindings

**Window & App Management:**
| Binding        | Action                                    |
|----------------|-------------------------------------------|
| Mod+P          | Lock screen (swaylock)                    |
| Mod+Tab        | Open kitty terminal                       |
| Mod+Space      | Rofi drun launcher                        |
| Mod+BackSpace  | Open floating kitty                       |
| Mod+W          | Open rmpc (music)                         |
| Mod+Shift+W    | Rescan MPD music library                  |
| Mod+T          | Open Zen browser                          |
| Mod+Shift+B    | Browse ~/Pictures/bgs with yazi           |
| Mod+B          | Random wallpaper (awww img, top transition) |
| Mod+D          | Open emacsclient (`emacsclient -c`)       |
| Mod+E          | Toggle eww desktop widgets                |
| Mod+Shift+E    | Kill eww                                  |
| Mod+Shift+P    | Quit DWL                                  |
| Mod+Shift+Q    | Kill focused client                       |
| Mod+Return     | Zoom (swap master/stack)                  |
| Mod+F          | Toggle floating                           |
| Mod+Shift+F    | Toggle fullscreen                         |

**Two-Key Chords (Mod+r then...):**
| Chord     | Action                  |
|-----------|------------------------|
| Mod+r, d  | Open Legcord (Discord) |
| Mod+r, b  | Open Brave             |
| Mod+r, a  | Open pavucontrol       |
| Mod+r, s  | Open Steam             |
| Mod+r, w  | Run runbar.sh          |

**Screenshots (Mod+s then...):**
| Chord     | Action                        |
|-----------|------------------------------|
| Mod+s, s  | Quick screenshot to clipboard |
| Mod+s, d  | Section screenshot + satty    |
| Mod+s, 1  | Full DP-1 screenshot          |
| Mod+s, 2  | Full DP-2 screenshot          |
| Mod+s, 3  | Full DP-3 screenshot          |

**Audio Effects (Mod+q then...):**
| Chord     | Action              |
|-----------|---------------------|
| Mod+q, 1  | `easyeffects -l EQ`   (stale — see note) |
| Mod+q, 2  | `easyeffects -l None` (stale — see note) |

> **Note:** These chords still call `easyeffects` in `config.h`, but EasyEffects has been removed. EQ is now a static PipeWire filter-chain (`sink-eq.conf`); switch the EQ'd output with `Alt+[` (flip.sh). The Mod+q chords are effectively no-ops until rebound.

**Media & Volume:**
| Binding        | Action                              |
|----------------|-------------------------------------|
| XF86AudioPlay  | MPD toggle play/pause               |
| XF86AudioPrev  | MPD previous track                  |
| XF86AudioNext  | MPD next track                      |
| Alt+Up         | Volume +5% (someblocks update)      |
| Alt+Down       | Volume -5%                          |
| Alt+Left       | Mic -5%                             |
| Alt+Right      | Mic +5%                             |
| Alt+End        | Mic mute toggle                     |
| Alt+[          | Cycle audio output sinks (flip.sh)  |
| Mod+Alt+Left   | Brightness -5%                      |
| Mod+Alt+Right  | Brightness +5%                      |
| Mod+Alt+Up     | Toggle gammastep (color temp)       |

**Focus & Layout:**
| Binding              | Action                     |
|----------------------|---------------------------|
| Mod+J/K              | Focus next/prev in stack  |
| Mod+H/L              | Resize master area        |
| Mod+M/N              | Decrease/increase master  |
| Mod+,/.              | Focus prev/next monitor   |
| Mod+Shift+</>        | Move window to prev/next monitor |
| Mod+Ctrl+Y/U/I       | Tile / Floating / Monocle layout |
| Arrow keys           | Move floating window      |
| Mod+Shift+Arrows     | Resize floating window    |

**Tags (workspaces):**
| Binding               | Action                      |
|-----------------------|-----------------------------|
| Mod+1–9              | View tag                    |
| Mod+Ctrl+1–9         | Toggle tag visibility        |
| Mod+Shift+!–(        | Move window to tag          |
| Mod+0                | View all tags               |

**Mouse:**
- Mod+Left drag: Move floating window
- Mod+Middle click: Toggle floating
- Mod+Right drag: Resize floating window

**Touchpad:**
- Tap: enabled, natural scroll: disabled, 2-finger scroll, DWT enabled, adaptive accel

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

### Key Aliases

| Alias      | Command                                   |
|------------|-------------------------------------------|
| gs         | git status -s                             |
| gac        | git add . && git commit -m               |
| gp         | git push                                  |
| vim        | nvim                                      |
| p          | paru                                      |
| ff         | fastfetch                                 |
| y          | yazi                                      |
| ta         | tmux attach-session -t                    |
| nord       | sudo systemctl start nordvpnd && nordvpn c Chicago |
| pickcolor  | grim+slurp+convert color picker           |
| doomsync   | pkill emacs → doom sync → restart service |

### FZF Integration
- Default: `fd --hidden --strip-cwd-prefix --exclude .git`
- Ctrl+T: find files, Ctrl+R: history, Alt+C: cd into directory

### History
- 1M entries, ignores duplicates, excludes: ls, cd, pwd, exit

### XDG Paths (from .zshenv)
- CONFIG: ~/.config, DATA: ~/.local/share, STATE: ~/.local/state, CACHE: ~/.cache
- ZDOTDIR: ~/.config/zsh
- All tool homes (cargo, rustup, go, npm, yarn, etc.) redirect to XDG_DATA_HOME
- EDITOR=nvim, JAVA_HOME=/usr/lib/jvm/java-21-openjdk

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
- Launched at session start by `autostart.sh` (`emacs --fg-daemon`); also available as a systemd user service (`systemctl --user start emacs`)
- `Mod+D` in DWL opens a client frame (`emacsclient -c`)
- `doomsync` alias handles sync: kill → doom sync → restart

---

## EWW Desktop Widgets

**Config:** `de/.config/eww/`
**Architecture:** Single config dir. The old `dash/` subdir was removed — `eww.yuck`/`eww.scss` now live at the eww root:
- `eww.yuck` — all widget + window definitions
- `eww.scss` — styling; does `@import "scale"` → reads the generated `_scale.scss`
- `_scale.scss` — generated at runtime by `eww.sh` (holds `$scale`); sits next to `eww.scss`
- `scripts/` — data provider scripts
- `calendar.url` — ICS/CalDAV URL for calendar widget

### Launch
```bash
~/.local/bin/eww.sh open     # all widgets (writes _scale.scss, reload, open each)
~/.local/bin/eww.sh close    # close all
```
`eww.sh` exposes only `open`/`close`. The daemon itself is started from DWL `autostart.sh` (`eww --config "$HOME/.config/eww" daemon`).

Monitor/scale detection: if DP-2 present → monitor 1 (desktop), scale `1.0`; else monitor 0 (laptop), scale `0.85`. `scale` drives **both** CSS sizes (`eww.scss` `s(n)` helper → `n*$scale*1px`, fed by `_scale.scss`) and window geometry (a per-window `scale` arg, since `defwindow :geometry` can't read globals).

### EWW Styling
`eww.scss` uses Catppuccin Mocha palette with `$border-radius: 0px` — all widgets are flat/sharp.

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

> **Note:** The volume sliders are not a standalone window — the `(volume)` widget is embedded inside the `mpd` widget. Older docs listed standalone `ram`/`disk`/`temps`/`hwinfo`/`procs`/`services`/`notes`/`updates`/`fetch` widgets; these were removed or folded into the windows above.

### EWW Scripts (de/.config/eww/scripts/)
- `ports.sh` — ss + awk + jq → JSON array of {proto, port, process}
- `calendar.sh` — Python (`events`, `refresh` subcommands): requires `icalendar` + `recurring_ical_events` (installed via home-manager); reads ~/.config/eww/calendar.url; caches ICS to /tmp/eww-calendar.ics
- `vpn-manager.sh` — OpenVPN management (`list`, `status`, `toggle`); state in /tmp/eww-openvpn.{pid,status,log}
- `focused-output.sh` — wlr-randr monitor detection

> **Note:** `procs.sh` and `services.sh` (in older versions of this file) are no longer present.

### EWW Dependencies
- jq — ports, notifications, net-graph (IP list)
- wl-gammarelay-rs + gdbus — brightness widget (software gamma dimming over the D-Bus session bus)
- mpc — mpd widget; wpctl — volume sliders (in mpd window)
- makoctl — notifications widget (history -j, mode toggle, dismiss)
- nvidia-smi — GPU usage + temp in the cpu widget
- curl — weather (wttr.in)
- python3 + `icalendar` + `recurring-ical-events` — calendar widget (managed by home-manager)
- wlr-randr — monitor detection in eww.sh
- Calendar URL config: `~/.config/eww/calendar.url` (ICS/CalDAV URL)

---

## Notification Daemon: mako

**Config:** `de/.config/mako/config`

Replaced dunst. mako is Wayland-native and `makoctl` talks D-Bus directly (via basu), so it needs no `busctl`/systemd — unlike `dunstctl history`, which is gated behind `busctl` and is therefore broken on Void. mako just needs the D-Bus **session bus** that `dbus-run-session dwl` already provides; it's launched from `autostart.sh` and inherits `DBUS_SESSION_BUS_ADDRESS` like any other DWL child. (Running `mako`/`makoctl`/`notify-send` from a terminal that lacks that env — e.g. one that survived a session restart — fails with "Could not connect" / "Failed to connect to user bus"; open a fresh DWL terminal.)

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
| setbg   | swww img       |
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

### mpDris (`de/.config/mpd/mpDris.conf`)
- Server: 127.0.0.1:6600

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

---

## Key Remapping: xremap

**Config:** `de/.config/xremap/config.yml`

### Keyboard Remaps

| From         | To           |
|--------------|--------------|
| Capslock     | Escape       |
| Keypad /     | Previous song |
| Keypad *     | Play/pause   |
| Keypad -     | Next song    |

### Mouse Remaps (G502 sensitivity button = F13)

| Combo            | Action      |
|------------------|-------------|
| F13 + Left click | Left        |
| F13 + Right click| Right       |

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

Logo: `source: auto`. Module order: Title, Separator, Host, CPU, GPU, Memory, Swap, Disk, Display, OS, Kernel, Bootloader, Init, Driver (custom command — nvidia/OpenGL/OpenCL/Vulkan versions), OS Age (custom — from `/` birth time), Seat Manager (custom — seatd/elogind/logind via xbps), Packages, WM, Login Manager (custom — scans `/var/service/` for greetd/gdm/etc.), Theme, Icons, Font, Cursor, Terminal, Shell.

The Driver, OS Age, Seat Manager, and Login Manager entries are `command`-type modules with inline shell that's Void-specific (uses `xbps-query` and runit's `/var/service/`).

---

## GTK / Qt Theming

**UI Aesthetic: flat/sharp** — all border-radius is 0 across GTK and eww. Enforced globally in `gtk-3.0/gtk.css` (sets `border-radius: 0px` on `*`, `window`, `button`, `entry`, `.titlebar`).

### GTK3 (`de/.config/gtk-3.0/`)
Now **stowed directly** as plain files (no longer home-manager–generated — `gtk.enable` was removed from home.nix). Edit the repo files and re-stow.
- Theme: `catppuccin-mocha-mauve-standard+default` (xbps package naming — note the `+default` suffix)
- Icons: **Papirus-Dark**
- Font: JetBrainsMono Nerd Font 14
- Cursor: Bibata-Modern-Classic, size 24
- `gtk-application-prefer-dark-theme = 0`
- `gtk.css` (border-radius override) also lives at `de/.config/gtk-3.0/gtk.css`

### GTK4 (`de/.config/gtk-4.0/`)
Also stowed directly. Contains `settings.ini`, `gtk.css`, `gtk-dark.css`, and `assets/`.

### xsettingsd (`de/.config/xsettingsd/xsettingsd.conf`)
XSETTINGS daemon for non-GTK/Qt apps (Firefox, Signal, Electron apps). Must be running for these apps to pick up dark theme and cursor settings.
- `Net/ThemeName` — catppuccin-mocha-mauve-standard+default
- `Net/IconThemeName` — Papirus-Dark
- `Gtk/CursorThemeName` — Bibata-Modern-Classic
- `Gtk/ApplicationPreferDarkTheme 1` — required for Firefox/Signal dark mode
- `Xft/Antialias` — 1
- `Xft/Hinting` — 1, hintslight
- `Xft/RGBA` — rgb

### Qt6 (`de/.config/qt6ct/qt6ct.conf`)
- Style: Kvantum
- Color: catppuccin-mocha-mauve
- Font: JetBrainsMono Nerd Font 13
- Single-click activation: yes

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

### eww.sh
Launches eww dashboard. Detects monitor via wlr-randr (DP-2 = desktop monitor 1, else monitor 0). Opens all dash widgets + VPN widget.

### screenshot.sh
- `ss` — quick screenshot to clipboard (grim+slurp)
- `section` — region screenshot → satty annotation
- `DP-1/2/3/HDMI-1/2` — full monitor → satty annotation
- Output: ~/Pictures/screenshot-YYYY-MM-DD_HH-MM-SS.png

### flip.sh
Cycles the default sink between the two EQ filter-chain sinks (`effect_input.eq_fiio` / `effect_input.eq_optical`) and migrates already-playing app streams to the new default. When switching to the optical EQ, first sets the USB2.0 card to its `iec958-stereo` profile so the chain's `target.object` resolves. Raw `alsa_output.*` sinks are intentionally excluded. Uses pactl.

### gammastep.sh
Toggles blue light filter: `gammastep -O 4000:4000`. Kill if running, start if not.

### brightness.sh
Software brightness for **all** outputs (laptop panel + the 3 externals) via `wl-gammarelay-rs` — dims the gamma curve per output, so it works on DP/HDMI monitors that have no `/sys/class/backlight`. Uses the D-Bus **session** bus dwl already provides (via `gdbus`, since Void has no `busctl`); no root/i2c. Subcommands: `up`/`down` (step ±5%), `set <0-100>` (the eww slider calls this), `get` (the eww poll reads this). Floor 10% (never fully black). Bound to Mod+Alt+Left/Right in DWL and drives the eww `brightness` widget.

### runbar.sh
Kills dwlb, restarts it, pipes someblocks status.

### svfzf
runit service manager: merges **system** and **user** services into one fzf list (bound to a floating kitty, like killfzf/clipfzf). Glyphs: `●` running, `○` enabled but stopped, `·` disabled. Keys: `enter` toggle running, `ctrl-e` enable + start, `ctrl-d` disable + stop, `ctrl-r` restart, `tab` multi-select, `esc` quit. The list re-renders after each action so you can toggle several in a row.

Two scopes, distinguished by a `[sys]`/`[usr]` column:
- **`[sys]`** — system services in `/etc/sv`, supervised via `/var/service` symlinks (root-owned; all actions use `sudo`, cached once up front). Enable/disable = add/remove the `/var/service` symlink.
- **`[usr]`** — user services in `~/.local/sv`, supervised directly by the per-user `runsvdir ~/.local/sv` from DWL autostart (no sudo). Because the dir **is** the supervised set (no symlink layer), enable/disable = `rm`/`touch` a `down` file inside the service dir; `down` present means runsv won't auto-start it. All user `sv` calls run with `SVDIR=~/.local/sv`.

### install.sh
Full system installation script. See [Installation & Setup](#installation--setup).

### install-tui.sh
Interactive fzf-based wrapper around install.sh. Multi-select menu for choosing which install modules to run. Catppuccin Mocha colored UI.

> **Note:** `lrc-extract.sh`, `kill.sh`, and `br0.sh` are documented in older versions of this file but are **not present** in `de/.local/bin/`. They may have been removed or never committed.

---

## Services

### User Services (runit, `~/.local/sv`)
Supervised by a per-user `runsvdir ~/.local/sv` started from DWL `autostart.sh` (replaced the old autostart-launched daemons — see commit "use runit services instead of an autostart"). Disable a service by dropping a `down` file in its dir (not by removing it — there's no symlink layer). Manage them with `svfzf` or `SVDIR=~/.local/sv sv <cmd> <name>`. Current set:
- dbus — persistent user D-Bus **session** bus (pinned via `DBUS_SESSION_BUS_ADDRESS` in DWL setupenv; the whole stack inherits it)
- pipewire, pipewire-pulse, wireplumber — audio
- mpd — Music Player Daemon
- mpDris2 — MPRIS interface for MPD
- emacs — Doom Emacs daemon
- syncthing
- wl-gammarelay-rs — gamma/brightness D-Bus service (drives brightness.sh + eww widget)
- swayidle — idle locker (`swayidle -w timeout 300 'swaylock -f'`)
- cliphist-text / cliphist-image — clipboard-history watchers (`wl-paste --type {text,image} --watch cliphist store`); two services, one per type

### System Services (runit, `/etc/sv` → `/var/service`)
Enable/disable via the `/var/service` symlink (managed by `svfzf` `[sys]` scope or `ln`/`rm` + `sv`).
- greetd — Display manager (tuigreet)
- ufw — Firewall
- bluetooth
- dbus
- udisks2 — Disk management
- nordvpnd — NordVPN daemon

---

## Package Management

**Primary: xbps** (Void Linux)
```bash
xbps-install -S <pkg>    # install
xbps-remove <pkg>        # remove
xbps-query -Rs <pkg>     # search
xbps-install -Su         # update system
```

**Secondary: Nix / home-manager** — for security tools, theming packages, Python libs
```bash
home-manager switch          # apply home.nix changes
nix-env -iA nixpkgs.<pkg>    # ad-hoc nix package
nix-collect-garbage -d       # remove old generations + garbage collect
```

---

## Git Workflow

```bash
gs    # git status -s
gac   # git add . && git commit -m
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
