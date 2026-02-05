#!/bin/bash
# Get listening ports with process names for eww widget

ss -tlnp 2>/dev/null | tail -n +2 | awk '
{
    # Extract local address:port
    split($4, addr, ":")
    port = addr[length(addr)]

    # Extract process name from users:(("name",...))
    process = ""
    if (match($0, /users:\(\("([^"]+)"/, m)) {
        process = m[1]
    } else if (match($6, /users:\(\("([^"]+)"/, m)) {
        process = m[1]
    } else {
        # Try alternative parsing
        if ($6 ~ /users:/) {
            gsub(/.*users:\(\("/, "", $6)
            gsub(/".*/, "", $6)
            process = $6
        }
    }

    # Skip if no port
    if (port == "" || port == "Local") next

    printf "{\"proto\":\"tcp\",\"port\":\"%s\",\"process\":\"%s\"}\n", port, process
}' | sort -t'"' -k4 -n | uniq | jq -sc '.'
