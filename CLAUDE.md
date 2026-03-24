# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal dotfiles for an Arch Linux system. Wayland compositor stack centered on DWL (custom-patched dwm port). GNU Stow manages all symlinks from `de/` to `$HOME`. Terminal emulator is **kitty** (not ghostty, not wezterm). Theme is **Catppuccin Mocha (Mauve accent)** across all applications.

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
- `install_system()` — enables pacman colors + multilib
- `install_packages()` — base, dev, terminal, wayland, audio, media, fonts, libraries
- `install_paru()` — AUR helper
- `install_aur()` — AUR: zen-browser-bin, brave-bin, xremap, legcord, catppuccin themes, eww
- `install_dwl()` — builds and installs dwl, dwlb, someblocks (binaries symlinked to /bin/)
- `install_grub()` — GRUB with Catppuccin Mocha theme
- `install_greetd()` — tuigreet display manager
- `install_swap()` — 16GB swapfile
- `install_shell()` — zsh + zplug, sets shell to /bin/zsh
- `install_zen()` — symlinks Zen browser configs
- `install_tpm()` — tmux plugin manager
- `install_services()` — enables: mpd, mpdris, xdg-desktop-portal, ufw, udisks2, bluetooth, dbus, greetd
- `install_nvidia()` — installs Nvidia packages from `~/dotfiles/nvidia-packages.txt` (opt-in, not in auto-run; available via install-tui.sh)

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

### Autostart (runs at DWL startup)
- dunst
- dwlb
- swww-daemon
- someblocks -p | dwlb -status-stdin
- easyeffects --gapplication-service
- gammastep -O 4000:4000
- nm-applet
- kitty --class rmpc rmpc
- wl-clip-persist --clipboard regular
- ~/.local/bin/eww.sh open

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
| Mod+B          | Random wallpaper (swww fade top)          |
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
| Mod+q, 1  | Load EQ preset      |
| Mod+q, 2  | Disable EQ (none)   |

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
- Font: JetBrainsMono Nerd Font 16
- Theme: catppuccin
- Line numbers: enabled
- Org directory: ~/org/

### Enabled Modules
- Completion: corfu (+orderless), vertico
- UI: doom, doom-dashboard, hl-todo, modeline, ophints, popup, vc-gutter, workspaces
- Editor: evil (vim bindings), file-templates, fold, snippets
- Emacs: dired, electric, undo, vc
- Terminal: vterm
- Checkers: syntax
- Tools: eval, lookup, magit, tree-sitter
- Languages: emacs-lisp, latex, lua, markdown, org, sh
- Default: +bindings, +smartparens

### Packages (packages.el)
- catppuccin-theme

### Systemd service
- `systemctl --user start emacs` — runs Emacs as daemon
- `doomsync` alias handles sync: kill → doom sync → restart

---

## EWW Desktop Widgets

**Config:** `de/.config/eww/`
**Architecture:** Multi-config (dash/ and vpn/ are separate eww instances)

### Launch
```bash
~/.local/bin/eww.sh open     # all widgets
~/.local/bin/eww.sh close    # close all
~/.local/bin/eww.sh dash     # dashboard only
~/.local/bin/eww.sh vpn      # toggle VPN widget
```

Monitor detection: if DP-2 present → monitor 1 (desktop), else monitor 0 (laptop)

### Dash Widgets (de/.config/eww/dash/eww.yuck)

| Widget        | Data Source                       | Interval | Notes                              |
|---------------|-----------------------------------|----------|------------------------------------|
| clock         | date command                      | 1s/60s   | Time + date                        |
| volume        | wpctl                             | 0.5s     | Speaker + mic, expandable sliders  |
| cpu-gpu-graph | EWW_CPU.avg + nvidia-smi          | 2s       | Overlaid line graphs               |
| tray          | systray (built-in)                | —        | System tray icons                  |
| ram           | EWW_RAM.used_mem_perc             | built-in | Circular progress                  |
| disk          | EWW_DISK["/"] + /proc/diskstats   | 1s       | Circular + R/W speed (nvme0n1)     |
| network       | /proc/net/dev (enp/wlan)          | 1s       | Upload/download MB/s               |
| temps         | /sys/class/thermal + nvidia-smi   | 2s       | CPU + GPU temp                     |
| weather       | wttr.in                           | 600s     | Temp, condition, humidity, wind    |
| notifications | dunstctl history + jq             | 2s       | Last 5 notifs, pause/clear buttons |
| mpd           | mpc                               | 1s       | Cover art, controls, progress bar  |
| updates       | checkupdates + yay                | 1800s    | Pacman + AUR update count          |
| fetch         | whoami, hostname, pacman, uptime  | 24h/60s  | System info display                |
| hwinfo        | /proc/cpuinfo, nvidia-smi, lsblk  | 24h      | CPU, GPU, disk, RAM, mobo          |
| ports         | scripts/ports.sh (ss + jq)        | 5s       | Listening TCP ports                |
| procs         | scripts/procs.sh (ps + jq)        | 2s       | Top 6 processes by CPU             |
| services      | scripts/services.sh (systemctl + jq) | 5s    | System + user services             |
| outlook       | scripts/calendar.sh (icalendar)   | 60s      | ICS calendar, next 7 days          |
| notes         | ~/.local/share/eww/notes.txt      | 5s       | Quick notes, edit with kitty+nvim  |

### EWW Scripts (de/.config/eww/scripts/)
- `ports.sh` — ss + awk + jq → JSON array of {proto, port, process}
- `procs.sh` — ps + awk + jq → JSON array of {pid, name, cpu, mem}
- `services.sh` — systemctl (system + user) + jq → JSON array of {name, status, type}
- `calendar.sh` — Python: requires `icalendar` + `recurring_ical_events` packages; reads ~/.config/eww/calendar.url; caches ICS to /tmp/eww-calendar.ics
- `vpn-manager.sh` — OpenVPN management; state in /tmp/eww-openvpn.{pid,status,log}
- `focused-output.sh` — wlr-randr monitor detection

### EWW Dependencies
- jq — required by ports, procs, services, notifications
- mpc — required by mpd widget
- dunstctl — notifications widget
- nvidia-smi — GPU stats
- curl — weather (wttr.in)
- python3 + `icalendar` + `recurring-ical-events` — calendar widget
- wlr-randr — monitor detection in eww.sh
- Notes file must exist: `~/.local/share/eww/notes.txt`
- Calendar URL config: `~/.config/eww/calendar.url` (ICS/CalDAV URL)

### Notes Widget Edit Button
Opens: `kitty nvim ~/.local/share/eww/notes.txt`

---

## Notification Daemon: dunst

**Config:** `de/.config/dunst/dunstrc`
- Monitor: 0
- Font: JetBrainsMono Nerd Font Regular 16
- Frame/separator color: #cba6f7 (mauve)
- Highlight: #cba6f7
- Urgency Low/Normal: bg #1e1e2e, fg #cdd6f4
- Urgency Critical: bg #1e1e2e, fg #cdd6f4, frame #fab387 (orange)

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

Modules: Title, CPU (P/E cores), GPU, Memory, Display, Disk, OS, Host/Mobo, Kernel, GPU detailed, Uptime, Packages, Shell, WM, Theme, Font, LM

---

## GTK / Qt Theming

### GTK3 (`de/.config/gtk-3.0/settings.ini`)
- Theme: catppuccin-mocha-mauve-standard+default
- Icons: Adwaita
- Font: JetBrainsMono Nerd Font 14
- Cursor: Adwaita, size 24
- XFT: antialias on, hint slight, RGB subpixel

### Qt6 (`de/.config/qt6ct/qt6ct.conf`)
- Style: Kvantum
- Color: catppuccin-mocha-mauve
- Font: JetBrainsMono Nerd Font 13
- Single-click activation: yes

### Kvantum (`de/.config/Kvantum/kvantum.kvconfig`)
- Theme: catppuccin-mocha-mauve

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
Cycles PipeWire audio output sinks (skips EasyEffects sink). Uses pactl.

### gammastep.sh
Toggles blue light filter: `gammastep -O 4000:4000`. Kill if running, start if not.

### runbar.sh
Kills dwlb, restarts it, pipes someblocks status.

### lrc-extract.sh
Extracts lyrics from FLAC metadata (UNSYNCED/LYRICS) and generates timed [MM:SS.MS] .lrc files. Uses: ffprobe, metaflac, bc.

### kill.sh
Interactive process killer via rofi dmenu. Filters out root/kernel threads. Sends kill -9.

### br0.sh
Creates network bridge br0, adds wlp2s0, assigns 192.168.1.10/24.

---

## Systemd Services

### User Services
- mpd — Music Player Daemon
- mpdris — MPRIS interface for MPD
- xdg-desktop-portal — Desktop portal
- emacs — Doom Emacs daemon

### System Services
- greetd — Display manager (tuigreet)
- ufw — Firewall
- bluetooth
- dbus
- udisks2 — Disk management
- nordvpnd — NordVPN daemon

---

## Package Management

- `pacman` / `paru` (AUR helper)
- Alias `p` = paru
- Alias `pf` = interactive AUR search with fzf

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
