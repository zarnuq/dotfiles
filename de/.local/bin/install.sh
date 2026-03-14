#!/bin/bash
mkdir -p ~/.config/zsh
mkdir -p ~/.local/share
mkdir -p ~/.local/src
mkdir -p ~/.local/bin
mkdir -p ~/.local/share

# Shared installation functions - can be sourced by other scripts
[[ -z "$SOURCED" ]] && set -e

log() { echo "$(tput setaf 2)==>$(tput sgr0) $*"; }

install_groups() {
  log "Adding user to groups"
  sudo groupadd nordvpn
  for group in power video storage kvm disk audio nordvpn mpd; do
    groups "$USER" | grep -qw "$group" || sudo usermod -aG "$group" "$USER"
  done
}

install_system() {
  log "Configuring pacman"
  sudo pacman -Syu --noconfirm
  sudo sed -i 's/^#Color/Color/' /etc/pacman.conf
  if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | sudo tee -a /etc/pacman.conf >/dev/null
    sudo pacman -Sy
  fi
}

install_packages() {
  log "Installing packages"
  packages=(
    base-devel git stow dash zsh tmux neovim vim man-db
    yazi fd fzf zoxide tree tldr fastfetch btop
    mpd rmpc playerctl easyeffects lsp-plugins
    kitty rofi-wayland dunst swaylock nemo pavucontrol nwg-look qt6ct
    swww wlr-randr grim slurp brightnessctl gammastep wtype
    mpv zathura loupe qbittorrent
    ufw udisks2 caligula
    rigprep wget tree-sitter-cli lua lua51 luarocks wlroots0.18 fcft pixman hyprland tllist wl-clip-persist eww network-manager-applet satty
    greetd greetd-tuigreet xdg-desktop-portal xdg-desktop-portal-wlr
    ttf-font-awesome otf-font-awesome ttf-jetbrains-mono-nerd noto-fonts-emoji noto-fonts-cjk
    papirus-icon-theme adwaita-fonts adwaita-cursors adw-gtk-theme
    github-cli
  )
  missing_pkgs=()
  for pkg in "${packages[@]}"; do
    pacman -Qq "$pkg" &>/dev/null || missing_pkgs+=("$pkg")
  done
  [[ ${#missing_pkgs[@]} -gt 0 ]] && sudo pacman -S --noconfirm "${missing_pkgs[@]}"
  tldr --update || true
  sudo rm -f /usr/share/applications/in.lsp_plug.lsp_plugins_*
}

install_paru() {
  if ! command -v paru &>/dev/null; then
    log "Installing paru"
    git clone https://aur.archlinux.org/paru.git /tmp/paru
    (cd /tmp/paru && makepkg -si --noconfirm)
    rm -rf /tmp/paru
    grep -q "BottomUp" /etc/paru.conf || echo "BottomUp" | sudo tee -a /etc/paru.conf >/dev/null
  fi
}

install_aur() {
  log "Installing AUR packages"
  aur_packages=(
    zen-browser-bin brave-bin mpdris-bin xremap-wlroots-bin legcord nordvpn-bin
    catppuccin-mocha-grub-theme-git catppuccin-gtk-theme-mocha
    kvantum-theme-catppuccin-git bibata-cursor-theme
  )
  for pkg in "${aur_packages[@]}"; do
    paru -Qq "$pkg" &>/dev/null || paru -S --noconfirm "$pkg"
  done
}

install_dwl() {
  log "Building window managers"
  for dir in dwl dwlb someblocks; do
    (cd ~/.local/src/"$dir" && make clean install 2>/dev/null || make)
    sudo ln -sf ~/.local/src/"$dir"/"$dir" /bin/"$dir"
  done
}

install_grub() {
  log "Configuring GRUB theme"
  if ! grep -q "catppuccin-mocha" /etc/default/grub; then
    sudo cp ~/dotfiles/de/Documents/logo.png /usr/share/grub/themes/catppuccin-mocha/logo.png
    echo 'GRUB_THEME="/usr/share/grub/themes/catppuccin-mocha/theme.txt"' | sudo tee -a /etc/default/grub >/dev/null
    sudo grub-mkconfig -o /boot/grub/grub.cfg
  fi
}

install_greetd() {
  log "Configuring greetd"
  sudo mkdir -p /etc/greetd
  sudo tee /etc/greetd/config.toml >/dev/null <<'EOF'
[terminal]
vt = 1

[default_session]
command = "/usr/bin/tuigreet -r --asterisks -c dwl"
user = "greeter"
EOF
}

install_swap() {
  log "Creating swapfile"
  if [[ ! -f /swapfile ]]; then
    sudo dd if=/dev/zero of=/swapfile bs=1G count=16 status=progress
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    grep -q "/swapfile" /etc/fstab || echo "/swapfile none swap defaults 0 0" | sudo tee -a /etc/fstab >/dev/null
  fi
}

install_shell() {
  log "Configuring shell"
  [[ "$SHELL" != "/bin/zsh" ]] && sudo chsh "$USER" -s /bin/zsh
  if [[ ! -f /etc/zsh/zshenv ]]; then
    sudo mkdir -p /etc/zsh
    echo "export ZDOTDIR=$HOME/.config/zsh" | sudo tee /etc/zsh/zshenv >/dev/null
  fi
  [[ "$(readlink /bin/sh)" != "/bin/dash" ]] && sudo ln -sf /bin/dash /bin/sh
  [[ ! -d ~/.local/share/zplug ]] && git clone https://github.com/zplug/zplug ~/.local/share/zplug
}

install_zen() {
  log "Configuring Zen browser"
  if [[ -f ~/.zen/profiles.ini ]]; then
    DEFAULT_PROFILE=$(grep -A1 '\[Install' ~/.zen/profiles.ini | grep '^Default=' | cut -d= -f2-)
    if [[ -n "$DEFAULT_PROFILE" ]]; then
      PROFILE_DIR="$HOME/.zen/$DEFAULT_PROFILE"
      ln -sf ~/dotfiles/de/.zen/chrome "$PROFILE_DIR"/chrome
      ln -sf ~/dotfiles/de/.zen/user.js "$PROFILE_DIR"/user.js
      xdg-settings set default-web-browser zen.desktop || true
    fi
  fi
}

install_tpm() {
  log "Installing tmux plugin manager"
  [[ ! -d ~/.local/share/tmux/plugins/tpm ]] && git clone https://github.com/tmux-plugins/tpm ~/.local/share/tmux/plugins/tpm
}

install_services() {
  log "Enabling services"
  mkdir -p ~/.local/share/mpd
  systemctl --user enable --now mpd mpdris xdg-desktop-portal 2>/dev/null || true
  sudo systemctl enable --now ufw bluetooth dbus udisks2
  sudo systemctl enable greetd
  sudo ufw --force enable
}

# Run all if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  install_groups
  install_system
  install_packages
  install_paru
  install_aur
  install_dwl
  install_grub
  install_greetd
  install_swap
  install_shell
  install_zen
  install_tpm
  install_services
  log "Installation complete! Reboot to apply all changes."
fi

