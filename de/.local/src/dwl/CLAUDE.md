# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a custom build of DWL (dwm for Wayland) - a dynamic tiling Wayland compositor based on wlroots. This build includes 14 custom patches that extend the base DWL functionality.

## Building and Installation

### Build Commands

Build DWL:
```bash
make clean
make
```

Install DWL (requires root):
```bash
make clean install
```

The Makefile installs to `/usr/local/bin/dwl` by default. The PREFIX variable in `config.mk` controls the installation path.

### Dependencies

Required packages (via pkg-config):
- wlroots-0.18
- wayland-server
- xkbcommon
- libinput
- xcb (for XWayland support)
- xcb-icccm (for XWayland support)

The build system automatically generates Wayland protocol headers using `wayland-scanner`.

### Configuration

**IMPORTANT**: Configuration is done by editing `config.h` directly (suckless-style). After modifying `config.h`, run `make clean` before rebuilding to ensure changes are compiled in.

If `config.h` doesn't exist, the Makefile will copy it from `config.def.h`.

## Architecture

### Core Files

- `dwl.c` - Main compositor implementation (~3500+ lines with patches)
- `config.h` - User configuration (keybindings, rules, monitor setup, autostart)
- `client.h` - Client window management macros
- `util.c` / `util.h` - Utility functions
- `dwl-ipc-unstable-v2-protocol.{c,h}` - IPC protocol for dwlb bar integration

### Applied Patches

Located in `patches/` directory. These patches fundamentally change DWL's behavior:

1. **autostart.patch** - Autostart applications array in config.h
2. **warpcursor.patch** - Warps cursor to focused window and monitor
3. **cursortheme.patch** - Custom cursor theme support
4. **customfloat.patch** - Floating window placement rules (x, y, width, height)
5. **monitorconfig.patch** - Extended monitor config (refresh rate, rotation, position)
6. **ipc.patch** - IPC support for external bar (dwlb)
7. **centerfloating.patch** - Centers new floating windows
8. **tmuxborder.patch** - Conditional borders (only when windows touch and focused)
9. **moveresizekb.patch** - Keyboard-based floating window resize/move
10. **switchtotag.patch** - Auto-switch to tag when window opens, restore on close
11. **regexrules.patch** - Regex pattern matching for window rules
12. **keepontag.patch** - Keep clients on same tag when moving between monitors
13. **keychords.patch** - Multi-key combinations (Emacs-style, e.g., Mod+r then d)
14. **setupenv.patch** - Environment variable array

### Key Configuration Patterns

**Keychord System**: Uses a custom macro-based keybinding system supporting multi-key chords:
```c
SPAWN1(MOD, p, "swaylock")  // Single key: Mod+p
SPAWN2(MOD, r, 0, d, "legcord")  // Chord: Mod+r then d
```

**Monitor Rules**: Multi-monitor setup with explicit positioning and rotation:
```c
{ "DP-3", 0.55f, 1, 1, &layouts[0], WL_OUTPUT_TRANSFORM_180, 0, 0, 3440, 1440, 0.0f, 1, 0 }
```
Fields: name, mfact, nmaster, scale, layout, rotation, x, y, width, height, refresh, mode, adaptive_sync

**Window Rules**: Supports regex patterns and custom floating positions:
```c
{ "^float", NULL, 0, 0, 1, -1, 0.25, 0.25, 0.5, 0.5 }
```
Fields: app_id, title, tags, switchtotag, isfloating, monitor, x, y, width, height (x/y/w/h as percentages)

**Autostart Array**: Null-terminated list of command arrays:
```c
{ "dunst", NULL,
  "dwlb", NULL,
  NULL }  // Terminator
```

### IPC Integration

DWL communicates with dwlb (status bar) via the dwl-ipc-unstable-v2 protocol. The bar shows:
- Current layout symbol
- Tag occupancy
- Window titles
- Status text from someblocks (piped via `-status-stdin`)

## Multi-Monitor Setup

This configuration manages 4 monitors:
- **eDP-1**: Laptop screen (1920x1200)
- **DP-3**: Primary ultrawide (3440x1440, rotated 180°)
- **DP-2**: Secondary ultrawide (3440x1440)
- **DP-1**: Vertical monitor (1920x1080, rotated 270°)

Monitor positioning in monrules uses absolute pixel coordinates. The x/y values position monitors in the virtual screen space.

## Modifying Configuration

### Adding Keybindings

Use the provided macros at the top of config.h:
- `SPAWN1(mod, key, ...)` - Single key spawn
- `SPAWN2(mod, key, mod2, key2, ...)` - Two-key chord
- `ACTION(mod, key, function)` - Single key action
- `TAG(key, shift_key, tag_num)` - Generate 4 tag-related bindings

### Adding Window Rules

Rules use regex matching (via regexrules patch). Patterns starting with `^` are treated as regex:
```c
{ "^steam", NULL, 1 << 4, 0, 0, -1, 0, 0, 0, 0 }  // Matches steam, steam_app, etc.
```

### Changing Layouts

Three layouts available:
- `[]=` - tile (master/stack)
- `><>` - floating
- `[M]` - monocle (fullscreen stack)

## Integration Points

- **dwlb**: Status bar (requires IPC patch)
- **someblocks**: Status block generator (output piped to dwlb)
- **xremap**: Key remapping daemon (started via autostart)
- **swww**: Wallpaper daemon
- **dunst**: Notification daemon
- **gammastep**: Color temperature adjustment

## Development Notes

- XWayland support is enabled via `XWAYLAND` define in config.mk
- Log level controlled by `log_level` variable in config.h (default: WLR_ERROR)
- The compositor uses wlroots scene graph API for rendering
- Border rendering is handled by tmuxborder patch (dynamic border visibility)
