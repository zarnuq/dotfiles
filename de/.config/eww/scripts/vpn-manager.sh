#!/bin/bash

# VPN Manager Script for EWW
# Requires a passwordless escalation rule for openvpn (and kill for disconnect).
# NOTE: doas/sudo match the command as typed, so we MUST call absolute paths that
# match the rule exactly (a bare "openvpn" will NOT match "cmd /usr/bin/openvpn"):
#   doas:     permit nopass <user> cmd /usr/bin/openvpn
#             permit nopass <user> cmd /usr/bin/kill
#   sudoers:  <user> ALL=(root) NOPASSWD: /usr/bin/openvpn, /usr/bin/kill

VPN_DIR="$HOME/VPNs"
PID_FILE="/tmp/eww-openvpn.pid"
STATUS_FILE="/tmp/eww-openvpn.status"
LOG_FILE="/tmp/eww-openvpn.log"

# Escalation command: prefer doas (this box symlinks sudo->doas), fall back to
# sudo so the script stays portable to sudoers systems.
if command -v doas >/dev/null 2>&1; then
    ESC=doas
elif command -v sudo >/dev/null 2>&1; then
    ESC=sudo
else
    ESC=""
fi

# Absolute binary paths — must match the doas/sudo rule exactly (see header).
OPENVPN_BIN=$(command -v openvpn 2>/dev/null || echo /usr/bin/openvpn)
KILL_BIN=/usr/bin/kill
[ -x "$KILL_BIN" ] || KILL_BIN=/bin/kill

list_vpns() {
    local vpns="["
    local first=true
    
    if [ -d "$VPN_DIR" ]; then
        for file in "$VPN_DIR"/*.ovpn; do
            [ -f "$file" ] || continue
            local name=$(basename "$file" .ovpn)
            
            if [ "$first" = true ]; then
                first=false
            else
                vpns+=","
            fi
            
            vpns+="{\"name\":\"$name\",\"file\":\"$file\"}"
        done
    fi
    
    vpns+="]"
    echo "$vpns"
}

get_status() {
    if [ -f "$STATUS_FILE" ] && [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        # Rootless liveness check: openvpn runs as root, so `kill -0` from a
        # normal user gets EPERM (not proof of death); /proc is world-readable.
        if [ -n "$pid" ] && [ -d "/proc/$pid" ] \
           && grep -qi openvpn "/proc/$pid/comm" 2>/dev/null; then
            cat "$STATUS_FILE"
            return
        fi
    fi
    echo ""
}

connect() {
    local config_file="$1"
    
    if [ ! -f "$config_file" ]; then
        notify-send "VPN Error" "Config file not found: $config_file" -u critical
        exit 1
    fi
    
    # Disconnect existing connection first
    disconnect 2>/dev/null
    
    local vpn_name=$(basename "$config_file" .ovpn)
    
    # Run openvpn elevated (passwordless rule required)
    $ESC "$OPENVPN_BIN" --config "$config_file" --daemon --log "$LOG_FILE" --writepid "$PID_FILE"

    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if [ -d "/proc/$pid" ]; then
            echo "$vpn_name" > "$STATUS_FILE"
            notify-send "VPN Connected" "Connected to $vpn_name" -u normal
        else
            notify-send "VPN Error" "Failed to connect. Check $LOG_FILE" -u critical
        fi
    else
        notify-send "VPN Error" "Failed to start OpenVPN. Check $LOG_FILE" -u critical
    fi
}

disconnect() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ]; then
            $ESC "$KILL_BIN" "$pid" 2>/dev/null
            sleep 1
            $ESC "$KILL_BIN" -9 "$pid" 2>/dev/null
        fi
        rm -f "$PID_FILE"
    fi
    
    if [ -f "$STATUS_FILE" ]; then
        local old_name=$(cat "$STATUS_FILE")
        rm -f "$STATUS_FILE"
        notify-send "VPN Disconnected" "Disconnected from $old_name" -u normal
    fi
}

toggle() {
    local config_file="$1"
    local vpn_name=$(basename "$config_file" .ovpn)

    if [ "$(get_status)" = "$vpn_name" ]; then
        disconnect
    else
        connect "$config_file"
    fi
}

case "$1" in
    list)
        list_vpns
        ;;
    status)
        get_status
        ;;
    connect)
        connect "$2"
        ;;
    disconnect)
        disconnect
        ;;
    toggle)
        toggle "$2"
        ;;
    *)
        echo "Usage: $0 {list|status|connect <file>|disconnect}"
        exit 1
        ;;
esac
