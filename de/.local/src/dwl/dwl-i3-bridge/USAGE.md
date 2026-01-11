# dwl-i3-bridge Usage Guide

## Quick Start

### 1. Build the Bridge

```bash
cd /home/miles/dotfiles/de/.local/src/dwl/dwl-i3-bridge
make
```

### 2. Start DWL

Make sure DWL is running with the IPC patch:

```bash
dwl
```

### 3. Start the Bridge

In a separate terminal or from DWL's autostart:

```bash
./dwl-i3-bridge
```

The bridge will:
- Connect to DWL's Wayland IPC
- Create a Unix socket at `$XDG_RUNTIME_DIR/dwl-ipc.sock`
- Set `$SWAYSOCK` environment variable
- Start translating DWL events to i3 IPC format

### 4. Start Noctalia Shell

Now you can start Noctalia Shell or any other Sway-compatible tool:

```bash
noctalia-shell
```

## Autostart with DWL

Add to your `dwl/config.h` autostart array:

```c
static const char *const autostart[] = {
    "/home/miles/dotfiles/de/.local/src/dwl/dwl-i3-bridge/dwl-i3-bridge", NULL,
    "noctalia-shell", NULL,
    NULL
};
```

Then rebuild DWL:

```bash
cd /home/miles/dotfiles/de/.local/src/dwl
make clean install
```

## Testing

Test the bridge with `i3-msg` (requires `i3-wm` package):

```bash
# Get workspaces (should show DWL tags as workspaces 1-9)
i3-msg -t get_workspaces

# Get outputs (should show your monitors)
i3-msg -t get_outputs

# Get version
i3-msg -t get_version

# Subscribe to workspace events
i3-msg -t subscribe -m '["workspace"]'
```

Or use the test script:

```bash
./test.sh
```

## Environment Variables

The bridge sets these automatically:

- `$SWAYSOCK` - Path to the i3 IPC socket (for Sway clients)
- `$I3SOCK` - Path to the i3 IPC socket (for i3 clients)

## DWL Tag → i3 Workspace Mapping

| DWL Tag | i3 Workspace Name |
|---------|-------------------|
| 1       | "1"               |
| 2       | "2"               |
| 3       | "3"               |
| 4       | "4"               |
| 5       | "5"               |
| 6       | "6"               |
| 7       | "7"               |
| 8       | "8"               |
| 9       | "9"               |

## Compatibility

### Works With:
- ✅ Noctalia Shell (Quickshell-based)
- ✅ Any tool using Quickshell.I3 module
- ✅ i3-msg command-line tool
- ✅ i3status, i3blocks (status bars)
- ✅ Tools expecting Sway/i3 IPC

### Does NOT Replace:
- ❌ DWL's native `dwl-ipc-unstable-v2` protocol
- ❌ dwlb (DWL's native bar still works via Wayland IPC)

Both protocols can run simultaneously!

## Troubleshooting

### "Failed to connect to DWL IPC"
- Make sure DWL is running
- Ensure DWL was built with the IPC patch
- Check that `$WAYLAND_DISPLAY` is set

### "Failed to start i3 IPC server"
- Check permissions on `$XDG_RUNTIME_DIR`
- Look for existing socket file: `ls -la $XDG_RUNTIME_DIR/dwl-ipc.sock`
- Kill any existing bridge process: `pkill dwl-i3-bridge`

### Noctalia Shell doesn't see workspaces
- Check that `$SWAYSOCK` is set: `echo $SWAYSOCK`
- Verify bridge is running: `pgrep dwl-i3-bridge`
- Test with i3-msg: `i3-msg -t get_workspaces`

### Events not updating
- The bridge broadcasts events when DWL state changes
- Try switching tags in DWL and check i3-msg output
- Enable debug output (modify source to add fprintf statements)

## Logs and Debugging

The bridge outputs to stderr:

```bash
dwl-i3-bridge 2>&1 | tee /tmp/bridge.log
```

Look for:
- "Found DWL IPC manager" - Connected to DWL
- "Bridge running (socket: ...)" - i3 IPC ready
- Monitor and tag updates

## Installation

Install system-wide:

```bash
sudo make install
```

This installs to `/usr/local/bin/dwl-i3-bridge`.

Then you can use it from anywhere:

```bash
dwl-i3-bridge
```

## Uninstallation

```bash
sudo make uninstall
```
