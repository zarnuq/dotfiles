#!/bin/sh
set -eu
export PATH=/usr/bin:/usr/sbin:/bin:/sbin

if [ "$(id -u)" != 0 ]; then
    echo 'Run this installer as root: sudo sh ydotool/runit/install.sh' >&2
    exit 1
fi
if [ "$(id -u miles)" != 1000 ] || [ "$(id -g miles)" != 1000 ]; then
    echo 'Expected miles to have UID/GID 1000:1000; review the service first.' >&2
    exit 1
fi
for executable in /usr/bin/modprobe /usr/bin/sv /usr/bin/svlogd \
    /home/miles/.nix-profile/bin/ydotool /home/miles/.nix-profile/bin/ydotoold; do
    if [ ! -x "$executable" ]; then
        echo "Missing executable: $executable" >&2
        exit 1
    fi
done
for destination in /etc/sv/ydotoold /service/ydotoold; do
    if [ -e "$destination" ] || [ -L "$destination" ]; then
        echo "Refusing to overwrite existing service: $destination" >&2
        exit 1
    fi
done
if [ ! -d /service ] || [ ! -d /etc/sv ]; then
    echo 'Expected the system runit directories /service and /etc/sv.' >&2
    exit 1
fi

source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ ! -c /dev/uinput ]; then
    /usr/bin/modprobe uinput
fi
if [ ! -c /dev/uinput ]; then
    echo 'uinput loaded, but /dev/uinput is missing; check device management.' >&2
    exit 1
fi
install -d -m 0755 /etc/sv/ydotoold/log /var/log/runit/ydotoold
install -m 0755 "$source_dir/ydotoold/run" /etc/sv/ydotoold/run
install -m 0755 "$source_dir/ydotoold/check" /etc/sv/ydotoold/check
install -m 0755 "$source_dir/ydotoold/log/run" /etc/sv/ydotoold/log/run
ln -s /etc/sv/ydotoold /service/ydotoold
# Let runsvdir discover the newly enabled service before sending commands.
attempt=0
while [ ! -p /etc/sv/ydotoold/supervise/ok ]; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge 10 ]; then
        echo 'Installed, but runsvdir has not discovered the service. Check /service supervision.' >&2
        exit 1
    fi
    sleep 1
done
if ! /usr/bin/sv -w 10 up /service/ydotoold; then
    echo 'Installed, but startup failed. Inspect /var/log/runit/ydotoold/current.' >&2
    exit 1
fi
/usr/bin/sv status /service/ydotoold
echo 'Installed and connected. Verify as miles with:'
echo 'YDOTOOL_SOCKET=/run/ydotoold/socket /home/miles/.nix-profile/bin/ydotool debug'
