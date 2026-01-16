#!/bin/sh
# Save as: $HOME/.local/src/someblocks/blocks/vpn.sh

# Check for VPN tunnel first
tun_ip=$(ip -4 addr show tun0 2>/dev/null | grep inet | awk '{print $2}' | cut -d/ -f1)

if [ -n "$tun_ip" ]; then
    echo "$tun_ip"
    exit 0
fi

# Check for WiFi interface
wifi_ip=$(ip -4 addr show wlp2s0 2>/dev/null | grep inet | awk '{print $2}' | cut -d/ -f1)

if [ -n "$wifi_ip" ]; then
    echo "$wifi_ip"
fi
