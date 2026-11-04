#!/usr/bin/env python3
"""Check Miles's desktop input connection, or read one Reach snapshot."""
import argparse
import json
import os
from pathlib import Path
import shutil
import socket
import stat
import subprocess
import sys


def binary(name):
    local = Path('/home/miles/.nix-profile/bin') / name
    return shutil.which(name) or (str(local) if os.access(local, os.X_OK) else None)


def state():
    path = str(Path(os.environ.get('XDG_RUNTIME_DIR', '/tmp')) / 'reach.sock')
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
            connection.settimeout(2)
            connection.connect(path)
            data = bytearray()
            while b'\n' not in data:
                chunk = connection.recv(4096)
                if not chunk:
                    raise ValueError('Disconnected before a complete snapshot')
                data.extend(chunk)
                if len(data) > 262144:
                    raise ValueError('Snapshot exceeded 256 KiB')
            print(json.dumps(json.loads(data.split(b'\n', 1)[0]), indent=2))
        return 0
    except (OSError, ValueError) as error:
        print(json.dumps({'socket': path, 'error': str(error)}))
        return 1


def check():
    client = binary('ydotool')
    runtime = os.environ.get('XDG_RUNTIME_DIR')
    explicit = os.environ.get('YDOTOOL_SOCKET')
    default = str(Path(runtime) / '.ydotool_socket') if runtime else '/tmp/.ydotool_socket'
    candidates = [explicit] if explicit else list(dict.fromkeys([
        default, '/run/ydotoold/socket', '/tmp/.ydotool_socket', '/home/miles/.ydotool_socket',
    ]))
    probes = []
    connected = None
    for path in candidates:
        try:
            is_socket = stat.S_ISSOCK(Path(path).stat().st_mode)
        except OSError:
            is_socket = False
        probe = {'path': path, 'is_socket': is_socket}
        if client:
            try:
                result = subprocess.run([client, 'debug'], env={**os.environ, 'YDOTOOL_SOCKET': path},
                                        capture_output=True, text=True, timeout=3)
                probe.update(returncode=result.returncode,
                             detail=(result.stdout + result.stderr).strip())
                if result.returncode == 0:
                    connected = path
            except (OSError, subprocess.TimeoutExpired) as error:
                probe['error'] = str(error)
        probes.append(probe)
        if connected:
            break
    report = {
        'ydotool': client, 'ydotoold': binary('ydotoold'),
        'session_type': os.environ.get('XDG_SESSION_TYPE'),
        'desktop': os.environ.get('XDG_CURRENT_DESKTOP'),
        'wayland_display': os.environ.get('WAYLAND_DISPLAY'),
        'uinput_visible': Path('/dev/uinput').exists(),
        'uinput_writable': os.access('/dev/uinput', os.W_OK),
        'connected_socket': connected, 'probes': probes,
        'tools': {name: binary(name) for name in (
            'river', 'reach', 'qs', 'grim', 'slurp', 'wlr-randr',
            'wl-copy', 'wl-paste', 'wf-recorder', 'ffmpeg', 'obsidian-cli',
        )},
    }
    print(json.dumps(report, indent=2))
    return 0 if connected else 1


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--state', action='store_true', help='Read one Reach state snapshot')
    arguments = parser.parse_args()
    sys.exit(state() if arguments.state else check())
