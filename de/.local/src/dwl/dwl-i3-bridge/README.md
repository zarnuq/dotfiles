# dwl-i3-bridge

A bridge daemon that translates DWL's Wayland IPC protocol to i3's IPC protocol, enabling Sway-compatible tools like Noctalia Shell to work with DWL.

## Overview

DWL uses the `dwl-ipc-unstable-v2` Wayland protocol for IPC, while many desktop shells (Noctalia, bars, etc.) expect Sway's i3-compatible IPC protocol. This bridge sits between them, translating:

- DWL **tags** → i3 **workspaces**
- DWL **monitors** → i3 **outputs**
- DWL **events** → i3 **events** (workspace, window, output)

## Building

Requirements:
- wayland-client
- DWL with ipc patch applied

```bash
make
```

## Installation

```bash
make install
```

Or manually copy the binary:

```bash
cp dwl-i3-bridge ~/.local/bin/
```

## Usage

1. Start DWL with the IPC patch
2. Run the bridge:
   ```bash
   dwl-i3-bridge
   ```
3. The bridge creates a Unix socket at `$XDG_RUNTIME_DIR/dwl-ipc.sock`
4. It automatically sets `$SWAYSOCK` and `$I3SOCK` environment variables
5. Launch Noctalia Shell or other Sway-compatible tools

## Environment Variables

- `$SWAYSOCK` - Set to the i3 IPC socket path (for Sway-compatible clients)
- `$I3SOCK` - Set to the i3 IPC socket path (for i3-compatible clients)
- `$XDG_RUNTIME_DIR` - Used to determine socket location

## i3 IPC Support

Currently implemented:
- `GET_WORKSPACES` - Returns DWL tags as workspaces (1-9)
- `GET_OUTPUTS` - Returns DWL monitors
- `GET_VERSION` - Returns version info
- `GET_TREE` - Basic window tree
- `SUBSCRIBE` - Subscribe to workspace/window/output events

Events:
- `workspace` - Sent when tags change or focus changes
- `window` - Sent when windows are created/destroyed/focused
- `output` - Sent when monitors are added/removed

## DWL Tag to i3 Workspace Mapping

DWL uses 9 tags (bitmask), this bridge maps them to i3 workspaces:

| DWL Tag | i3 Workspace |
|---------|--------------|
| Tag 1   | Workspace 1  |
| Tag 2   | Workspace 2  |
| ...     | ...          |
| Tag 9   | Workspace 9  |

## Compatibility

This bridge does NOT replace DWL's existing `dwl-ipc-unstable-v2` protocol. Tools like `dwlb` (DWL bar) will continue to work using the native Wayland protocol. This bridge only provides an *additional* i3-compatible interface for tools that expect Sway/i3 IPC.

## Testing

Test with `i3-msg`:
```bash
# Get workspaces
i3-msg -t get_workspaces

# Get outputs
i3-msg -t get_outputs

# Subscribe to workspace events
i3-msg -t subscribe -m '["workspace"]'
```

## License

Same as DWL (GPL-3.0)

## Author

Created for DWL + Noctalia Shell compatibility
