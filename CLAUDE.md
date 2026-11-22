# CLAUDE.md

Personal dotfiles for a **Gentoo** desktop and laptop. This file holds only what applies anywhere in the repo. Each area's details are in a nested `CLAUDE.md` that loads when you work there (index below), so read the files themselves for exact keys and values.

## Overview

- Wayland stack on **reach**, a custom Zig river WM (dwl-like desktops, master/stack tiling, window rules). reach draws no bar: it publishes state on a socket and **quickshell** draws the whole desktop UI. Terminal **kitty**. Theme **Catppuccin Mocha, Mauve accent**, everywhere. UI is flat: `border-radius: 0` explicitly everywhere.
- **GNU Stow** links `de/` into `$HOME`. Setup: clone, `stow de`, `home-manager switch --flake ~/.config/home-manager#miles`. `stow -D de` removes the links. Some `$HOME` dirs are unfolded (one link per item: `~/.agents`, `~/.claude/skills`, `~/.local/bin`), so a new file there needs its link added by hand or a re-stow.
- **Portage** first, **nix/home-manager** (a flake) second. Elevation is `doas`, with no `sudo` and no symlink. doas matches the command **as typed against the rule as written**: `permit nopass :wheel cmd poweroff` needs the bare `poweroff`, not `/usr/bin/poweroff`. Check any invocation with `doas -C /etc/doas.conf <cmd>`, which executes nothing.
- **No polkit agent is possible:** polkit is built `-elogind -systemd`, so there is no active session and `allow_active=yes` defaults fail. Grant what's used with `/etc/polkit-1/rules.d/*.rules` returning `polkit.Result.YES` (currently `50-udisks-plugdev.rules` for the quickshell drives menu). quickshell is built `-policykit` for the same reason.
- Previously Void Linux; no stale Void/dwl leftovers remain (cleared 2026-09-25). Add new finds here. rofi is gone: quickshell's launcher owns `Super+Space`.

## Layout

```
de/                  stowed to $HOME
  .agents/           AGENTS.md (global instructions for every CLI), skills/, ctf/ and redteam/ libraries
  .claude/ .codex/ .vibe/ .gemini/   links into .agents/ plus per-CLI settings; never stow these dirs whole
  .config/           app configs
  .local/bin/        scripts        .local/sv/  runit user services
kernels/             saved kernel .configs, seeds for rebuild-kernel.sh -c (not stowed)
tests/               quickshell lint and QML unit tests
.claude/skills/      project skills: `quickshell`
```

## Where the details are (nested `CLAUDE.md`, loaded on demand)

| Area | File |
|---|---|
| reach WM: reload, monitor layouts, gamma, state socket, rules, binds | `de/.config/reach/CLAUDE.md` |
| quickshell: features, conventions, component notes | `de/.config/quickshell/CLAUDE.md` (+ `music/`) |
| theme-set palette switching and its consumers | `de/.config/theme/CLAUDE.md` |
| nix / home-manager, the overlay pins, nix GL vs nvidia | `de/.config/home-manager/CLAUDE.md` |
| PipeWire EQ sinks, `flip.sh` | `de/.config/pipewire/CLAUDE.md` |
| MPD and mpd-mpris, media keys | `de/.config/mpd/CLAUDE.md` |
| beets vs `~/mux` (who owns the music library) | `de/.config/beets/CLAUDE.md` |
| zsh: zhimmer, the Ctrl+R unbinds, the nix login-shell fix | `de/.config/zsh/CLAUDE.md` |
| scripts (`flip.sh`, `svfzf`, `rebuild-kernel.sh` …) and runit services | `de/.local/CLAUDE.md` |
| AI agent config: skills, libraries, zq, agents, settings.json | `de/.agents/CLAUDE.md` |
| tests | `tests/CLAUDE.md` |

## Always relevant

- **reach rejects a config with an unknown key.** A reload with a parse error keeps the running config, but at startup reach falls back to compiled-in defaults: no binds, no layout. A binary that adds or drops a key must land with the `config.zon` that uses it. Reload with `Super+Shift+r` or `kill -HUP $(pidof reach)`.
- **reach owns gamma.** wl-gammarelay-rs, wlsunset and gammastep must not run.
- **quickshell** runs as the runit user service `quickshell` with software rendering. Restart: `SVDIR=~/.local/sv sv restart quickshell`. IPC is `qs ipc call <target> open|hide|toggle`, never `show`.
- **Palette:** Base `#1e1e2e` · Surface0 `#313244` · Surface1 `#45475a` (borders) · Text `#cdd6f4` · Subtext0 `#a6adc8` · **Mauve `#cba6f7` (accent)** · Overlay0 `#6c7086` · Overlay1 `#7f849c` · Blue `#89b4fa` · Green `#a6e3a1` · Peach `#fab387` (warn) · Red `#f38ba8` · Teal `#94e2d5` · Yellow `#f9e2af` · Lavender `#b4befe`. Live colours come from `theme-set`.
- **GTK/Qt:** GTK3/4 are stowed plain files (`gtk-3.0/gtk.css` enforces radius 0). Theme `catppuccin-mocha-mauve-standard+default`, Papirus-Dark icons, JetBrainsMono Nerd Font, Bibata-Modern-Classic cursor. `de/.config/dconf/interface.dconf` is `dconf load`ed by reach autostart and carries `color-scheme='prefer-dark'`; there is no xsettingsd. Qt6 goes through qt6ct with Kvantum.
- **Small configs:** kitty (class `float` is used by reach binds), tmux (prefix `Ctrl+F`), nvim (lazy.nvim, leader Space), yazi (`O` on an image sets the wallpaper via `qs ipc call wallpaper set`), btop, Zen (chrome CSS rendered by theme-set). xdg portals use `default=wlr;gtk`.
- **Git aliases:** `gs` · `gac "msg"` (add . + commit) · `gp`. Git commands still need my OK each session.
