#!/bin/bash
# Get all services for eww widget (excluding systemd-* services)

{
    # System services (excluding systemd-*)
    systemctl list-units --type=service --no-pager --no-legend 2>/dev/null | while read -r unit load active sub rest; do
        name="${unit%.service}"
        [[ "$name" == systemd-* ]] && continue
        name="${name//\\/\\\\}"
        name="${name//\"/\\\"}"
        printf '{"name":"%s","status":"%s","type":"system"}\n' "$name" "$active"
    done

    # User services (excluding systemd-*)
    systemctl --user list-units --type=service --no-pager --no-legend 2>/dev/null | while read -r unit load active sub rest; do
        name="${unit%.service}"
        [[ "$name" == systemd-* ]] && continue
        name="${name//\\/\\\\}"
        name="${name//\"/\\\"}"
        printf '{"name":"%s","status":"%s","type":"user"}\n' "$name" "$active"
    done
} | jq -sc '.'
