# ydotoold runit service

This service targets Miles's machine: UID/GID `1000:1000`, Nix-profile
executables, and the system runit scan directory `/service`.

Install from the repository root in a local terminal:

```sh
sudo sh ydotool/runit/install.sh
```

The installer refuses to overwrite an existing service. It loads `uinput`,
installs the service under `/etc/sv/ydotoold`, enables it through `/service`,
and checks socket connectivity. The service loads `uinput` on subsequent
boots when needed. Keep ydotool installed in Miles's Nix profile.

The daemon runs as root to access `/dev/uinput`. Its socket is owned by
Miles with mode `0600`; the device permissions remain unchanged. Logs go
to `/var/log/runit/ydotoold/current` with rotation managed by `svlogd`.

Verify from Miles's shell without emitting input:

```sh
export YDOTOOL_SOCKET=/run/ydotoold/socket
/home/miles/.nix-profile/bin/ydotool debug
python3 ydotool/scripts/inspect_desktop.py
```

Set `YDOTOOL_SOCKET` in the agent's launch environment to use this socket.
The repository's inspector also probes it automatically. Sandboxed agents
still need permission to connect to this Unix socket; a healthy host service
does not remove that restriction. Restart the agent after changing its environment.

```sh
sudo sv status /service/ydotoold
sudo sv restart /service/ydotoold
sudo tail -n 30 /var/log/runit/ydotoold/current
```

To disable and remove the service:

```sh
sudo sv down /service/ydotoold
sudo rm /service/ydotoold
sudo rm -r /etc/sv/ydotoold
```

Logs are retained. Stop any independently started ydotool daemon before
enabling this service, to avoid duplicate virtual input devices.
