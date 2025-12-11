# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal dotfiles repository for an Arch Linux system with a focus on Wayland compositors (primarily DWL and River). The repository uses GNU Stow for symlink management.

## Repository Structure

- `de/` - Desktop environment configuration directory (stowed to `$HOME`)
  - `.config/` - Application configurations
  - `.local/bin/` - Custom shell scripts and utilities
  - `.local/src/` - Local source code for window managers (dwl, dwlb, someblocks)
  - `.local/share/` - Shared data files
  - `.zen/` - Zen browser customizations
- `archive/` - Archived configurations
- `screenshots/` - Screenshots for README

## Installation and Setup

### Initial Installation

```bash
cd ~
git clone https://github.com/zarnuq/dotfiles.git
cd dotfiles
stow de
~/.local/bin/install.sh
```

The `install.sh` script handles:
- Adding user to required groups (power, video, storage, kvm, disk, audio, nordvpn, mpd)
- Installing base Arch packages and AUR packages via paru
- Building and installing custom DWL (with patches), dwlb, and someblocks
- Configuring greetd, GRUB theme, swap, shell (zsh), and Zen browser
- Enabling systemd services (mpd, mpdris, xdg-desktop-portal, ufw, bluetooth, dbus, udisks2, greetd)

### Building Window Managers

Build the custom DWL window manager with patches:
```bash
cd ~/.local/src/dwl
make clean install
```

Build the DWL bar (dwlb):
```bash
cd ~/.local/src/dwlb
make clean install
```

Build someblocks status bar:
```bash
cd ~/.local/src/someblocks
make
```

After building, the binaries are symlinked to `/bin/` by the install script.

## Custom DWL Window Manager

The DWL configuration at `de/.local/src/dwl/config.h` includes custom patches:
- autostart - Autostart applications in config.h
- warpcursor - Warps cursor to active window and monitor
- cursortheme - Custom cursor theme support
- customfloat - Rules for floating window placement
- monitorconfig - Extended monitor parameters (refresh rate, rotation, etc.)
- ipc - IPC support for dwlb
- centerfloating - Centers new floating windows
- tmuxborder - Conditional borders (only when touching another window and focused)
- moveresizekb - Keyboard shortcuts for moving/resizing floating windows
- switchtotag - Auto-switch to tag on window open, restore on close
- regexrules - Regex support for window rules
- keepontag - Custom patch to keep clients on same tag when moving between monitors
- keychords - Multi-key combos like Emacs (e.g., Mod+o then t)
- setupenv - Array for setting environment variables

### DWL Configuration Details

Monitor setup in config.h:
- eDP-1: Laptop screen (1920x1200)
- DP-3: Primary ultrawide (3440x1440)
- DP-2: Secondary ultrawide (3440x1440)
- DP-1: Vertical monitor (1920x1080, rotated 270°)

Environment variables set via DWL:
- XDG_CURRENT_DESKTOP=sway (for compatibility)
- XDG_SESSION_TYPE=wayland
- QT_QPA_PLATFORMTHEME=qt6ct
- QT_STYLE_OVERRIDE=kvantum

## Key Applications and Tools

### Desktop Widgets (eww)

The eww configuration at `de/.config/eww/eww.yuck` provides desktop widgets:
- Clock with time and date
- CPU/GPU usage graphs (supports nvidia-smi)
- RAM and disk usage circular indicators
- Network speed monitor (upload/download)
- Temperature monitors (CPU/GPU)
- System uptime
- Weather widget (uses wttr.in)
- Notification center (dunst integration)
- MPD music player controls
- System updates counter (checkupdates + yay)

Launch eww widgets with `~/.local/bin/eww.sh`

### Shell Configuration

ZSH with custom configuration at `de/.config/zsh/.zshrc`:
- Uses zplug for plugin management
- Starship prompt (though config shows Spaceship variables)
- Key aliases: `y` (yazi), `gs` (git status -s), `vim` (nvim), `p` (paru)
- History: 1M entries, ignores duplicates

### Neovim

Uses lazy.nvim plugin manager. Configuration structure:
- `de/.config/nvim/init.lua` - Entry point
- `de/.config/nvim/lua/core/keymaps.lua` - Key mappings
- `de/.config/nvim/lua/core/spell.lua` - Spell checking
- `de/.config/nvim/lua/plugins/` - Plugin specifications

### Other Configured Applications

- **btop** - System monitor
- **dunst** - Notification daemon
- **doom emacs** - Emacs distribution
- **easyeffects** - PipeWire audio effects (runs as systemd service)
- **fastfetch** - System info
- **ghostty** - Terminal emulator
- **GTK/Qt themes** - Catppuccin Mocha theme with Kvantum
- **kitty/wezterm** - Terminal emulators
- **mpd + rmpc** - Music Player Daemon with rust client
- **rofi** - Application launcher (Wayland version)
- **swaylock** - Screen locker
- **swww** - Wallpaper daemon
- **tmux** - Terminal multiplexer with tpm plugin manager
- **xremap** - Key remapping tool (runs at startup)
- **yazi** - File manager
- **zen-browser** - Custom themed browser

## Custom Scripts

Located in `de/.local/bin/`:
- `install.sh` - Main system setup script
- `eww.sh` - Launch eww widgets
- `screenshot.sh` - Screenshot utility (uses grim/slurp)
- `lrc-extract.sh` / `lrc-extract-all.sh` - Extract lyrics from audio files
- `gammastep.sh` - Blue light filter wrapper
- `flip.sh` - Unknown utility
- `br0.sh` - Network bridge script
- `runbar.sh` - Status bar launcher
- `kali-tools.sh` - Kali Linux tools installer

## Stow Management

This repository uses GNU Stow. To apply configurations:
```bash
stow de
```

To remove symlinks:
```bash
stow -D de
```

The `.gitignore` excludes:
- tmux plugin directory
- UUID files
- lazy-lock.json (Neovim)
- MPD runtime files (log, state, db, pid)
- Playlist files (*.m3u)
- Neovim spell files

## Systemd Services

User services:
- mpd - Music Player Daemon
- mpdris - MPRIS interface for MPD
- xdg-desktop-portal - Desktop portal

System services:
- greetd - Display manager
- ufw - Firewall
- bluetooth
- dbus
- udisks2 - Disk management

## Git Workflow

Common git aliases defined in zshrc:
- `gs` - `git status -s` (short status)
- `gac` - `git add . && git commit -m` (add all and commit)
- `gp` - `git push`

## Package Management

Uses `paru` (AUR helper) and `pacman`:
- `p` alias for paru
- `pf` - Interactive AUR search with preview using fzf
