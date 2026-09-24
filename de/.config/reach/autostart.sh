#!/bin/sh
trap 'kill 0' EXIT TERM INT

runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime/bus"
pgrep -f "runsvdir $HOME/.local/sv" >/dev/null || \
	setsid runsvdir "$HOME/.local/sv" >/dev/null 2>&1 &
bus="$runtime/bus"
while [ ! -S "$bus" ]; do sleep 0.05; done

# Retries until quickshell's IPC is up. `show` would exit 0 without reaching
# the handler (it collides with the `qs ipc show` subcommand), so: toggle.
(
	i=0
	while [ "$i" -lt 100 ]; do
		qs ipc call music toggle >/dev/null 2>&1 && break
		i=$((i + 1))
		sleep 0.1
	done
) &

dconf load /org/gnome/desktop/interface/ < "$HOME/.config/dconf/interface.dconf"
wait
