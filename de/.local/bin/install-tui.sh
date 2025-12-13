#!/bin/bash

# Check if fzf is available
if ! command -v fzf &>/dev/null; then
  echo "fzf not found. Installing fzf..."
  sudo pacman -S --noconfirm fzf
fi

# ============================================================================
# Module Functions
# ============================================================================

install_groups() {
  echo ">>> Adding user to system groups..."
  group_list=(power video storage kvm disk audio nordvpn mpd)
  for group in "${group_list[@]}"; do
    if ! groups "$USER" | grep -qw "$group"; then
      sudo usermod -a -G "$group" "$USER"
    fi
  done
  echo "✓ Groups added"
  echo ""
}

install_system() {
  echo ">>> Updating system and configuring pacman..."
  sudo pacman -Syu --noconfirm
  if ! grep -Fxq "[multilib]" /etc/pacman.conf; then
    echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | sudo tee -a /etc/pacman.conf
  fi
  if ! grep -Fxq "Color" /etc/pacman.conf; then
    echo -e "\n[options]\nColor" | sudo tee -a /etc/pacman.conf
  fi
  echo "✓ System updated and pacman configured"
  echo ""
}

install_base_packages() {
  echo ">>> Installing base packages from Arch repositories..."
  packages=(base-devel yazi stow rmpc mpd easyeffects neovim kitty wezterm fastfetch river rofi-wayland zsh pavucontrol zathura hyprland gammastep wtype nemo brightnessctl swaybg wlr-randr vlc mpv github-cli git fd fzf zoxide tree vim btop dunst ufw udisks2 greetd greetd-tuigreet ttf-font-awesome otf-font-awesome ttf-jetbrains-mono-nerd papirus-icon-theme adwaita-fonts adwaita-cursors adw-gtk-theme grim slurp xdg-desktop-portal xdg-desktop-portal-wlr dash nwg-look swaylock man-db tmux 7zip steam lsp-plugins bluez blueberry glow starship imagemagick noto-fonts-emoji loupe tldr playerctl qbittorrent qt6ct ghostwriter noto-fonts-cjk emacs)
  missing_pkgs=()
  for pkg in "${packages[@]}"; do
    pacman -Qq "$pkg" &>/dev/null || missing_pkgs+=("$pkg")
  done
  if (( ${#missing_pkgs[@]} )); then
    sudo pacman -S --noconfirm "${missing_pkgs[@]}"
  fi
  tldr --update
  sudo rm /usr/share/applications/in.lsp_plug.lsp_plugins_* 2>/dev/null
  echo "✓ Base packages installed"
  echo ""
}

install_paru() {
  echo ">>> Installing paru AUR helper..."
  if ! command -v paru &>/dev/null; then
    git clone https://aur.archlinux.org/paru.git ~/paru
    (cd ~/paru && makepkg -si --noconfirm)
    rm -rf ~/paru
    echo "BottomUp" | sudo tee -a /etc/paru.conf
    echo "✓ Paru installed"
  else
    echo "✓ Paru already installed"
  fi
  echo ""
}

install_dwl() {
  echo ">>> Building and installing DWL window manager..."
  cd ~/.local/src/dwl
  make clean install
  cd ~/.local/src/dwlb
  make clean install
  cd ~/.local/src/someblocks
  make
  cd ~
  sudo ln -sf ~/.local/src/dwl/dwl /bin/dwl
  sudo ln -sf ~/.local/src/dwlb/dwlb /bin/dwlb
  sudo ln -sf ~/.local/src/someblocks/someblocks /bin/someblocks
  echo "✓ DWL window manager installed"
  echo ""
}

install_aur_packages() {
  echo ">>> Installing AUR packages..."
  if ! command -v paru &>/dev/null; then
    echo "✗ Paru not installed! Please install paru module first."
    return 1
  fi
  aur_packages=(zen-browser-bin brave-bin mpdris-bin xremap-wlroots-bin yambar catppuccin-mocha-grub-theme-git catppuccin-gtk-theme-mocha bibata-cursor-theme legcord kvantum-theme-catppuccin-git nordvpn-bin)
  for pkg in "${aur_packages[@]}"; do
    paru -Qq "$pkg" &>/dev/null || paru -S --noconfirm "$pkg"
  done
  echo "✓ AUR packages installed"
  echo ""
}

install_grub() {
  echo ">>> Configuring GRUB theme..."
  if ! grep "catppuccin-mocha" /etc/default/grub; then
    sudo rm /usr/share/grub/themes/catppuccin-mocha/logo.png 2>/dev/null
    sudo cp ~/dotfiles/de/Documents/logo.png /usr/share/grub/themes/catppuccin-mocha
    echo 'GRUB_THEME="/usr/share/grub/themes/catppuccin-mocha/theme.txt"' | sudo tee -a /etc/default/grub
    sudo grub-mkconfig -o /boot/grub/grub.cfg
    echo "✓ GRUB themed"
  else
    echo "✓ GRUB already themed"
  fi
  echo ""
}

install_greetd() {
  echo ">>> Configuring greetd login manager..."
  if [ ! -f /etc/greetd/config.toml ]; then
    sudo mkdir -p /etc/greetd
    sudo tee /etc/greetd/config.toml > /dev/null <<EOF
[terminal]
vt = 1

[default_session]
command = "/usr/bin/tuigreet -r --asterisks -c dwl"
user = "greeter"
EOF
    echo "✓ Greetd configured"
  else
    echo "✓ Greetd already configured"
  fi
  echo ""
}

install_swap() {
  echo ">>> Creating swap file..."
  if [ ! -f "/swapfile" ]; then
    sudo dd if=/dev/zero of=/swapfile bs=1G count=16 status=progress
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo "/swapfile none swap defaults 0 0" | sudo tee -a /etc/fstab
    echo "✓ Swap file created"
  else
    echo "✓ Swap file already exists"
  fi
  echo ""
}

install_shell() {
  echo ">>> Configuring shell (ZSH and dash)..."
  if [ "$SHELL" != "/bin/zsh" ]; then
    sudo chsh "$USER" -s /bin/zsh
  fi
  if [ ! -f /etc/zsh/zshenv ]; then
    sudo mkdir -p /etc/zsh
    echo "export ZDOTDIR=/home/$USER/.config/zsh" | sudo tee /etc/zsh/zshenv
  fi
  sudo rm -f /bin/sh
  sudo ln -s /bin/dash /bin/sh
  if [ ! -d ~/.local/share/zplug ]; then
    git clone https://github.com/zplug/zplug ~/.local/share/zplug
  fi
  echo "✓ Shell configured"
  echo ""
}

install_zen() {
  echo ">>> Configuring Zen browser theme..."
  if [ -f "$HOME/.zen/profiles.ini" ]; then
    DEFAULT_PROFILE=$(grep -A1 '\[Install' "$HOME/.zen/profiles.ini" | grep '^Default=' | cut -d= -f2-)
    PROFILE_DIR="$HOME/.zen/$DEFAULT_PROFILE"
    rm -rf "$PROFILE_DIR"/chrome
    rm -rf "$PROFILE_DIR"/user.js
    ln -s ~/dotfiles/de/.zen/chrome "$PROFILE_DIR"/chrome
    ln -s ~/dotfiles/de/.zen/user.js "$PROFILE_DIR"/user.js
    xdg-settings set default-web-browser zen.desktop
    echo "✓ Zen browser configured"
  else
    echo "✗ Zen profiles.ini not found. Please run Zen browser first."
    return 1
  fi
  echo ""
}

install_doom() {
  echo ">>> Installing Doom Emacs..."
  if [ ! -d ~/.config/emacs ]; then
    git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.config/emacs
    sh ~/.config/emacs/bin/doom install
    echo "✓ Doom Emacs installed"
  else
    echo "✓ Doom Emacs already installed"
  fi
  echo ""
}

install_tpm() {
  echo ">>> Installing Tmux Plugin Manager..."
  if [ ! -d ~/.local/share/tmux/plugins/tpm ]; then
    git clone https://github.com/tmux-plugins/tpm ~/.local/share/tmux/plugins/tpm
    echo "✓ TPM installed"
  else
    echo "✓ TPM already installed"
  fi
  echo ""
}

install_services() {
  echo ">>> Enabling and starting systemd services..."
  mkdir -p ~/.local/share/mpd
  systemctl --user enable --now mpd 2>/dev/null
  systemctl --user enable --now mpdris 2>/dev/null
  systemctl --user enable --now xdg-desktop-portal 2>/dev/null
  sudo systemctl enable --now ufw
  sudo systemctl enable --now bluetooth
  sudo systemctl enable --now dbus
  sudo systemctl enable --now udisks2
  sudo systemctl enable greetd
  sudo ufw enable
  echo "✓ Services enabled and started"
  echo ""
}

# ============================================================================
# Main Script
# ============================================================================

# Define modules with descriptions
modules=(
  "groups - Add user to system groups (power, video, etc.)"
  "system - System update and pacman configuration"
  "base_packages - Install base Arch packages"
  "paru - Install paru AUR helper"
  "dwl - Build and install DWL window manager"
  "aur_packages - Install AUR packages (zen-browser, etc.)"
  "grub - Configure GRUB theme (Catppuccin)"
  "greetd - Configure greetd login manager"
  "swap - Create 16GB swap file"
  "shell - Configure ZSH shell and dash"
  "zen - Configure Zen browser theme"
  "doom - Install Doom Emacs"
  "tpm - Install Tmux Plugin Manager"
  "services - Enable and start systemd services"
)

# Show fzf menu
clear
echo "╭─────────────────────────────────────────────────────────────────────╮"
echo "│                     Dotfiles Installation Menu                      │"
echo "╰─────────────────────────────────────────────────────────────────────╯"

# Use fzf with multi-select
SELECTED=$(printf '%s\n' "${modules[@]}" | \
  fzf --multi \
      --height=80% \
      --border=rounded \
      --prompt="Select modules > " \
      --pointer="▶" \
      --marker="✓ " \
      --header="TAB: toggle | ENTER: confirm | ESC: cancel | Ctrl-A: select all" \
      --color="fg:#cdd6f4,bg:#1e1e2e,hl:#f38ba8" \
      --color="fg+:#cdd6f4,bg+:#313244,hl+:#f38ba8" \
      --color="info:#cba6f7,prompt:#cba6f7,pointer:#f5e0dc" \
      --color="marker:#a6e3a1,spinner:#f5e0dc,header:#94e2d5" \
      --reverse \
      --bind='ctrl-a:select-all')

# Check if user cancelled
if [ $? -ne 0 ] || [ -z "$SELECTED" ]; then
  echo ""
  echo "Installation cancelled."
  exit 1
fi

echo ""
echo "=========================================="
echo "Starting installation of selected modules"
echo "=========================================="
echo ""

# Function to check if module is selected
is_selected() {
  echo "$SELECTED" | grep -q "^$1 -"
}

# Run selected modules
is_selected "groups" && install_groups
is_selected "system" && install_system
is_selected "base_packages" && install_base_packages
is_selected "paru" && install_paru
is_selected "dwl" && install_dwl
is_selected "aur_packages" && install_aur_packages
is_selected "grub" && install_grub
is_selected "greetd" && install_greetd
is_selected "swap" && install_swap
is_selected "shell" && install_shell
is_selected "zen" && install_zen
is_selected "doom" && install_doom
is_selected "tpm" && install_tpm
is_selected "services" && install_services

echo ""
echo "=========================================="
echo "Installation complete!"
echo "=========================================="
echo ""
echo "Please reboot your system to apply all changes."
