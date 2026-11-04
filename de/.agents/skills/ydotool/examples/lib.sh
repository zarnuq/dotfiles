# Shared helpers for the example scripts. Source it; don't execute it.
# zsh does not word-split "$cmd args", so wrap commands in functions, not strings.
skill_dir=$(cd "$(dirname "$0")/.." && pwd)

ui() { timeout 30 /usr/bin/python3 -W ignore "$skill_dir/scripts/ui.py" "$@"; }

y() {
    YDOTOOL_SOCKET=${YDOTOOL_SOCKET:-/run/ydotoold/socket} \
        /home/miles/.nix-profile/bin/ydotool "$@" >/dev/null
}

# key CODE... : tap a chord, e.g. `key 29 30` = Ctrl+A (press in order, release in reverse).
key() {
    down= up=
    for code in "$@"; do down="$down $code:1"; up="$code:0 $up"; done
    # shellcheck disable=SC2086
    y key $down $up
    sleep 0.2
}

text() { y type --escape=0 -- "$1"; sleep 0.2; }

# expect LABEL ACTUAL WANTED : fail loudly so later input never runs blind.
expect() {
    if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$2', want '$3'" >&2; exit 1; fi
}

# active_window : title of the focused accessible window, empty when focus is elsewhere
# (kitty, Obsidian). Reach's --state title can lag pointer focus, so don't use it here.
active_window() { ui apps | sed -n 's/^[^|]* | \(.*\) | active$/\1/p'; }
