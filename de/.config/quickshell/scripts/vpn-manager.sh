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
LOG_FILE="/tmp/eww-openvpn.log"

# Escalation command: prefer doas (the only one installed here), fall back to
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

# Every pid running an openvpn whose --config lives in $VPN_DIR. Scoped to that
# directory on purpose: NetworkManager's own openvpn plugin runs configs out of
# /var/run/NetworkManager and must never be caught by this.
vpn_pids() {
    local pid args
    for pid in $(pgrep -x openvpn 2>/dev/null); do
        args=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null) || continue
        case "$args" in
            *"--config $VPN_DIR/"*) printf '%s\n' "$pid" ;;
        esac
    done
}

# The profile name of the running tunnel, or "".
#
# Ground truth is the PROCESS TABLE, not a marker file. It used to be
# /tmp/eww-openvpn.status, which connect() wrote only `if [ -f "$PID_FILE" ]` — but
# openvpn is started with --daemon and forks immediately, so the pid file it
# writes with --writepid usually isn't there yet when connect() looks. The
# status file therefore never got written, this function always printed "", and
# every UI showed a live tunnel as disconnected — which is how Enter on an
# already-connected profile started a SECOND daemon for the same config and
# left an orphaned tun device the pid file no longer tracked.
#
# /proc/<pid>/cmdline is world-readable even though openvpn runs as root, so
# this needs no elevation (`kill -0` would only give EPERM).
get_status() {
    local pid args name
    for pid in $(vpn_pids); do
        args=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null) || continue
        name=${args#*--config $VPN_DIR/}
        name=${name%% *}
        printf '%s\n' "${name%.ovpn}"
        return
    done
}

connect() {
    local config_file="$1"
    
    if [ ! -f "$config_file" ]; then
        notify-send "VPN Error" "Config file not found: $config_file" -u critical
        exit 1
    fi
    
    local vpn_name=$(basename "$config_file" .ovpn)

    # Never stack a second daemon on a config that already has one. This is the
    # guard, not the caller's: the UI can only ask for what it last polled, and
    # anything that made get_status lie (as the status file did) turned a
    # connect into a duplicate tunnel.
    if [ "$(get_status)" = "$vpn_name" ]; then
        notify-send "VPN" "$vpn_name is already connected" -u normal
        return 0
    fi

    # Only then drop whatever else is up — one lab tunnel at a time.
    disconnect 2>/dev/null
    
    # Run openvpn elevated (passwordless rule required)
    $ESC "$OPENVPN_BIN" --config "$config_file" --daemon --log "$LOG_FILE" --writepid "$PID_FILE"

    # Wait for the PROCESS, not the pid file — same fork race as above, which
    # is why this used to announce a failure for a tunnel that had just come up.
    local i=0
    while [ $i -lt 20 ] && [ "$(get_status)" != "$vpn_name" ]; do
        sleep 0.1
        i=$((i + 1))
    done

    if [ "$(get_status)" = "$vpn_name" ]; then
        notify-send "VPN Connected" "Connected to $vpn_name" -u normal
    else
        notify-send "VPN Error" "Failed to start OpenVPN. Check $LOG_FILE" -u critical
    fi
}

disconnect() {
    local was=$(get_status)

    # Every matching daemon, not just the pid file's: the file tracks only the
    # most recent one, so an earlier failed kill left an orphan that nothing
    # could stop afterwards. This is also what cleans such an orphan up.
    local pids=$(vpn_pids) pid failed=""
    for pid in $pids; do
        if ! $ESC "$KILL_BIN" "$pid" 2>/dev/null; then failed="$failed $pid"; fi
    done
    if [ -n "$pids" ]; then
        sleep 1
        for pid in $(vpn_pids); do $ESC "$KILL_BIN" -9 "$pid" 2>/dev/null; done
    fi
    rm -f "$PID_FILE"

    # A kill that silently failed is why the duplicate could exist at all: the
    # rule is matched as typed, so this needs `permit nopass miles cmd /usr/bin/kill`.
    if [ -n "$failed" ]; then
        notify-send "VPN Error" "could not stop openvpn (pid$failed) — needs a doas nopass rule for $KILL_BIN" -u critical
    fi
    
    [ -n "$was" ] && notify-send "VPN Disconnected" "Disconnected from $was" -u normal
    return 0
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
