#!/bin/sh
# Test script for dwl-i3-bridge

echo "Testing dwl-i3-bridge..."
echo

# Check if DWL is running
if ! pgrep -x dwl > /dev/null; then
    echo "ERROR: DWL is not running"
    echo "Please start DWL first"
    exit 1
fi

# Start the bridge
echo "Starting dwl-i3-bridge..."
./dwl-i3-bridge &
BRIDGE_PID=$!

# Wait for socket to be created
sleep 1

if [ -z "$SWAYSOCK" ]; then
    echo "ERROR: \$SWAYSOCK not set"
    kill $BRIDGE_PID
    exit 1
fi

echo "Bridge running (PID: $BRIDGE_PID)"
echo "Socket: $SWAYSOCK"
echo

# Test with i3-msg if available
if command -v i3-msg > /dev/null; then
    echo "Testing i3 IPC commands:"
    echo

    echo "1. GET_VERSION:"
    i3-msg -t get_version
    echo

    echo "2. GET_WORKSPACES:"
    i3-msg -t get_workspaces
    echo

    echo "3. GET_OUTPUTS:"
    i3-msg -t get_outputs
    echo
else
    echo "i3-msg not found, skipping IPC tests"
    echo "Install i3-wm package to test"
fi

echo "Bridge is running. Press Ctrl+C to stop."
wait $BRIDGE_PID
