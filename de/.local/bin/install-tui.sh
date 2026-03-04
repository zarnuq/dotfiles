#!/bin/bash

# Source shared installation functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SOURCED=1
source "$SCRIPT_DIR/install.sh"

# Check if fzf is available
if ! command -v fzf &>/dev/null; then
  echo "Installing fzf..."
  sudo pacman -S --noconfirm fzf
fi

# Define modules
modules=(
  "groups - Add user to system groups"
  "system - Configure pacman and update system"
  "packages - Install base packages"
  "paru - Install paru AUR helper"
  "aur - Install AUR packages"
  "dwl - Build window managers (dwl, dwlb, someblocks)"
  "grub - Configure GRUB theme"
  "greetd - Configure greetd login manager"
  "swap - Create 16GB swap file"
  "shell - Configure ZSH and dash"
  "zen - Configure Zen browser"
  "tpm - Install tmux plugin manager"
  "services - Enable systemd services"
)

# Show menu
clear
echo "╭──────────────────────────────────────────────────────╮"
echo "│           Dotfiles Installation Menu                │"
echo "╰──────────────────────────────────────────────────────╯"

SELECTED=$(printf '%s\n' "${modules[@]}" | \
  fzf --multi \
      --height=80% \
      --border=rounded \
      --prompt="Select modules > " \
      --pointer="▶" \
      --marker="✓ " \
      --header="j/k: nav | TAB: toggle | ENTER: confirm | ESC: cancel | Ctrl-A: all" \
      --color="fg:#cdd6f4,bg:#1e1e2e,hl:#f38ba8" \
      --color="fg+:#cdd6f4,bg+:#313244,hl+:#f38ba8" \
      --color="info:#cba6f7,prompt:#cba6f7,pointer:#f5e0dc" \
      --color="marker:#a6e3a1,spinner:#f5e0dc,header:#94e2d5" \
      --reverse \
      --bind='j:down,k:up,ctrl-d:half-page-down,ctrl-u:half-page-up,ctrl-f:page-down,ctrl-b:page-up,ctrl-a:select-all')

[[ $? -ne 0 || -z "$SELECTED" ]] && echo -e "\nInstallation cancelled." && exit 1

echo -e "\n=========================================="
echo "Starting installation"
echo "==========================================\n"

is_selected() { echo "$SELECTED" | grep -q "^$1 -"; }

# Run selected modules
is_selected "groups" && install_groups
is_selected "system" && install_system
is_selected "packages" && install_packages
is_selected "paru" && install_paru
is_selected "aur" && install_aur
is_selected "dwl" && install_dwl
is_selected "grub" && install_grub
is_selected "greetd" && install_greetd
is_selected "swap" && install_swap
is_selected "shell" && install_shell
is_selected "zen" && install_zen
is_selected "tpm" && install_tpm
is_selected "services" && install_services

echo -e "\n=========================================="
echo "Installation complete!"
echo "=========================================="
echo -e "\nReboot to apply all changes."
