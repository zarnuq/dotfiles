#!/bin/bash

# VPN Manager Script for EWW
# Requires: sudoers entry for openvpn and kill

VPN_DIR="$HOME/VPNs"
PID_FILE="/tmp/eww-openvpn.pid"
STATUS_FILE="/tmp/eww-openvpn.status"
LOG_FILE="/tmp/eww-openvpn.log"

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
        if [ -n "$pid" ] && sudo kill -0 "$pid" 2>/dev/null; then
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
    
    # Run openvpn with sudo (passwordless via sudoers)
    sudo openvpn --config "$config_file" --daemon --log "$LOG_FILE" --writepid "$PID_FILE"
    
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if sudo kill -0 "$pid" 2>/dev/null; then
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
            sudo kill "$pid" 2>/dev/null
            sleep 1
            sudo kill -9 "$pid" 2>/dev/null
        fi
        rm -f "$PID_FILE"
    fi
    
    if [ -f "$STATUS_FILE" ]; then
        local old_name=$(cat "$STATUS_FILE")
        rm -f "$STATUS_FILE"
        notify-send "VPN Disconnected" "Disconnected from $old_name" -u normal
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
    *)
        echo "Usage: $0 {list|status|connect <file>|disconnect}"
        exit 1
        ;;
esac
