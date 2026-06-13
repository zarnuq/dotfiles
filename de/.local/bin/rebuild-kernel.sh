#!/usr/bin/env bash
# rebuild-kernel.sh — rebuild the gentoo-sources kernel + UKI on a lazygentoo box,
# re-sign it for Secure Boot, and re-register the efibootmgr entry. All the heavy
# lifting (initramfs, UKI assembly, signing, efibootmgr) happens in the single
# `kernel-install add` at the end via the install.d hooks.
#
# TPM2 needs no reseal: PCR 7 measures the Secure Boot policy, not the UKI, and the
# new UKI is signed with the already-enrolled key (keys live in /etc/kernel/uki.conf).
set -euo pipefail

SRC=/usr/src/linux
JOBS=$(nproc)
CONFIG=
DO_EMERGE=0
ASSUME_YES=0

usage() {
  cat <<EOF
Usage: rebuild-kernel.sh [-e] [-c CONFIG] [-j JOBS] [-y]

  -e          emerge --update --newuse sys-kernel/gentoo-sources first
              (pulls a newer kernel version, repoints /usr/src/linux)
  -c CONFIG   seed .config from CONFIG (default: keep \$SRC/.config; after a
              version bump, fall back to the running config in /proc/config.gz)
  -j JOBS     parallel make jobs (default: nproc = $JOBS)
  -y          don't prompt before building
  -h          this help

Examples:
  rebuild-kernel.sh                 rebuild current kernel with its existing .config
  rebuild-kernel.sh -e              emerge a newer gentoo-sources, then rebuild
  rebuild-kernel.sh -c CONFIG       rebuild from a specific .config file
  rebuild-kernel.sh -e -y           bump + rebuild, no prompt
EOF
}

# help shouldn't require root
case "${1:-}" in -h|--help) usage; exit 0 ;; esac

# elevate via doas (this box symlinks sudo -> doas)
if [ "$(id -u)" -ne 0 ]; then
  exec doas "$0" "$@"
fi

while getopts 'ec:j:yh' o; do
  case "$o" in
    e) DO_EMERGE=1 ;;
    c) CONFIG=$OPTARG ;;
    j) JOBS=$OPTARG ;;
    y) ASSUME_YES=1 ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

# Capture the running kernel's config NOW — before any emerge moves the symlink to
# a fresh source tree that has no .config of its own.
RUNNING_CFG=$(mktemp)
trap 'rm -f "$RUNNING_CFG"' EXIT
if [ -r /proc/config.gz ]; then
  zcat /proc/config.gz > "$RUNNING_CFG"
elif [ -r "$SRC/.config" ]; then
  cp "$SRC/.config" "$RUNNING_CFG"
fi

if [ "$DO_EMERGE" -eq 1 ]; then
  echo ">> emerging newer gentoo-sources..."
  emerge --update --newuse --quiet-build sys-kernel/gentoo-sources
fi

[ -d "$SRC" ] || { echo "no $SRC — is gentoo-sources installed with USE=symlink?" >&2; exit 1; }

# Choose the config to build from.
if [ -n "$CONFIG" ]; then
  install -m644 "$CONFIG" "$SRC/.config"
elif [ ! -f "$SRC/.config" ]; then
  # fresh source tree after a version bump -> seed from the running config
  [ -s "$RUNNING_CFG" ] || { echo "no .config in $SRC and no running config to seed from; pass -c CONFIG" >&2; exit 1; }
  install -m644 "$RUNNING_CFG" "$SRC/.config"
fi

# olddefconfig absorbs version drift; resolve the real kver afterward.
make -C "$SRC" olddefconfig
KVER=$(make -s -C "$SRC" kernelrelease)

echo ">> building kernel $KVER (jobs=$JOBS)"
if [ "$ASSUME_YES" -ne 1 ]; then
  read -rp "proceed? [y/N] " a
  [ "$a" = y ] || [ "$a" = Y ] || exit 1
fi

make -C "$SRC" -j"$JOBS"
make -C "$SRC" INSTALL_MOD_STRIP=1 modules_install

# Feed the bzImage straight from the source tree (NOT `make install`, which has been
# seen to update /boot/vmlinuz yet skip the UKI rebuild -> stale UKI). This one call
# builds the initramfs+UKI, signs it (ukify, keys from uki.conf), prunes old UKIs,
# and rewrites the efibootmgr entry — all via /etc/kernel/install.d hooks.
kernel-install add "$KVER" "$SRC/arch/x86/boot/bzImage"

echo ">> done. UKIs in /boot/EFI/Linux:"
ls -lt /boot/EFI/Linux/ 2>/dev/null | head
if command -v sbctl >/dev/null; then
  echo ">> signature check:"
  sbctl verify | grep -F "$KVER" || echo "  (no sbctl match for $KVER — check `sbctl verify`)"
fi
echo ">> reboot to run $KVER"
