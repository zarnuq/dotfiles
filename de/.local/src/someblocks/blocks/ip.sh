#!/bin/bash
# Get IP of the active (default route) network interface
iface=$(ip route show default 2>/dev/null | awk '/default/ { print $5; exit }')
if [ -z "$iface" ]; then
    echo "no link"
    exit
fi
ip=$(ip -4 addr show "$iface" | awk '/inet / { print $2 }' | cut -d/ -f1)
if [ -z "$ip" ]; then
    echo "no ip"
    exit
fi
echo " $iface: $ip"
