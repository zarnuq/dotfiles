#!/bin/bash
set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Error handler
trap 'log_error "Script failed at line $LINENO"' ERR

# Summary tracking
declare -a COMPLETED_STEPS=()
declare -a FAILED_STEPS=()

mark_complete() {
    COMPLETED_STEPS+=("$1")
}

mark_failed() {
    FAILED_STEPS+=("$1")
}

# ============================================================================
# SYSTEM GROUPS
# ============================================================================
setup_groups() {
    log_info "Setting up user groups..."
    local groups=(power video storage kvm disk audio nordvpn mpd)
    local added=0

    for group in "${groups[@]}"; do
        if ! groups "$USER" | grep -qw "$group"; then
            if sudo groupadd -f "$group" 2>/dev/null && sudo usermod -aG "$group" "$USER"; then
                ((added++))
            fi
        fi
    done

    if ((added > 0)); then
        log_success "Added $added group(s). Re-login required for changes to take effect."
    else
        log_success "All groups already configured"
    fi
    mark_complete "User groups"
}

# ============================================================================
# PACMAN CONFIGURATION
# ============================================================================
configure_pacman() {
    log_info "Configuring pacman..."
    local modified=0

    # Enable multilib
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | sudo tee -a /etc/pacman.conf >/dev/null
        ((modified++))
        log_success "Enabled multilib repository"
    fi

    # Enable color output
    if ! grep -q "^Color" /etc/pacman.conf; then
        sudo sed -i 's/^#Color/Color/' /etc/pacman.conf
        ((modified++))
        log_success "Enabled pacman color output"
    fi

    # Enable parallel downloads
    if ! grep -q "^ParallelDownloads" /etc/pacman.conf; then
        sudo sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf
        ((modified++))
        log_success "Enabled parallel downloads"
    fi

    if ((modified > 0)); then
        sudo pacman -Sy --noconfirm
    else
        log_success "Pacman already configured"
    fi
    mark_complete "Pacman configuration"
}

# ============================================================================
# SYSTEM PACKAGES
# ============================================================================
install_system_packages() {
    log_info "Installing system packages..."

    local packages=(
        # Base development
        base-devel git

        # Shell and terminal
        zsh dash tmux kitty

        # display manager
        greetd greetd-tuigreet

        # Wayland utilities
        rofi grim slurp wlr-randr swaylock swww
        xdg-desktop-portal xdg-desktop-portal-wlr

        # Audio
        mpd easyeffects pavucontrol lsp-plugins

        # System utilities
        brightnessctl ufw udisks2 bluez blueberry 7zip 

        # File managers and viewers
        yazi nemo zathura loupe stow 

        # Monitoring and system info
        btop fastfetch eww

        # Notifications
        dunst

        # Text editors
        neovim vim emacs

        # Media
        mpv vlc qbittorrent rmpc yt-dlp

        # Document tools
        glow

        # Command line tools
        fd fzf zoxide tree playerctl
        tealdeer github-cli

        # Graphics and screenshots
        imagemagick wtype gammastep qt6ct 

        # Fonts and themes
        ttf-font-awesome otf-font-awesome ttf-jetbrains-mono-nerd
        noto-fonts-emoji noto-fonts-cjk
        papirus-icon-theme adwaita-fonts adwaita-cursors adw-gtk-theme

        # Other
        steam
    )

    # Filter already installed packages
    local to_install=()
    for pkg in "${packages[@]}"; do
        if ! pacman -Qq "$pkg" &>/dev/null; then
            to_install+=("$pkg")
        fi
    done

    if ((${#to_install[@]} > 0)); then
        log_info "Installing ${#to_install[@]} package(s)..."
        sudo pacman -S --needed --noconfirm "${to_install[@]}"
        log_success "Installed ${#to_install[@]} system packages"
    else
        log_success "All system packages already installed"
    fi

    # Update tldr database
    tldr --update &>/dev/null || true

    # Remove unwanted desktop files
    sudo rm -f /usr/share/applications/in.lsp_plug.lsp_plugins_* 2>/dev/null || true

    mark_complete "System packages"
}

# ============================================================================
# AUR HELPER (PARU)
# ============================================================================
install_paru() {
    log_info "Setting up paru AUR helper..."

    if command -v paru &>/dev/null; then
        log_success "Paru already installed"
        mark_complete "Paru AUR helper"
        return 0
    fi

    local temp_dir=$(mktemp -d)
    git clone https://aur.archlinux.org/paru.git "$temp_dir"
    (cd "$temp_dir" && makepkg -si --noconfirm)
    rm -rf "$temp_dir"

    # Configure paru
    if ! grep -q "^BottomUp" /etc/paru.conf 2>/dev/null; then
        echo "BottomUp" | sudo tee -a /etc/paru.conf >/dev/null
    fi

    log_success "Paru installed and configured"
    mark_complete "Paru AUR helper"
}

# ============================================================================
# AUR PACKAGES
# ============================================================================
install_aur_packages() {
    log_info "Installing AUR packages..."

    if ! command -v paru &>/dev/null; then
        log_error "Paru not found, skipping AUR packages"
        mark_failed "AUR packages"
        return 1
    fi

    local aur_packages=(
        zen-browser-bin
        brave-bin
        mpdris-bin
        xremap-wlroots-bin
        catppuccin-mocha-grub-theme-git
        catppuccin-gtk-theme-mocha
        bibata-cursor-theme
        legcord
        kvantum-theme-catppuccin-git
        nordvpn-bin
        tidal-dl-ng
        tidal-hifi-bin
    )

    local to_install=()
    for pkg in "${aur_packages[@]}"; do
        if ! paru -Qq "$pkg" &>/dev/null; then
            to_install+=("$pkg")
        fi
    done

    if ((${#to_install[@]} > 0)); then
        log_info "Installing ${#to_install[@]} AUR package(s)..."
        paru -S --needed --noconfirm "${to_install[@]}"
        log_success "Installed ${#to_install[@]} AUR packages"
    else
        log_success "All AUR packages already installed"
    fi

    mark_complete "AUR packages"
}

# ============================================================================
# DWL WINDOW MANAGER
# ============================================================================
build_dwl() {
    log_info "Building DWL window manager and components..."

    local src_dir="$HOME/.local/src"
    local built=0

    # Build DWL
    if [[ -d "$src_dir/dwl" ]]; then
        (cd "$src_dir/dwl" && make clean install)
        sudo ln -sf "$src_dir/dwl/dwl" /bin/dwl
        ((built++))
    else
        log_warn "DWL source not found at $src_dir/dwl"
    fi

    # Build dwlb (bar)
    if [[ -d "$src_dir/dwlb" ]]; then
        (cd "$src_dir/dwlb" && make clean install)
        sudo ln -sf "$src_dir/dwlb/dwlb" /bin/dwlb
        ((built++))
    else
        log_warn "dwlb source not found at $src_dir/dwlb"
    fi

    # Build someblocks
    if [[ -d "$src_dir/someblocks" ]]; then
        (cd "$src_dir/someblocks" && make)
        sudo ln -sf "$src_dir/someblocks/someblocks" /bin/someblocks
        ((built++))
    else
        log_warn "someblocks source not found at $src_dir/someblocks"
    fi

    if ((built > 0)); then
        log_success "Built $built DWL component(s)"
        mark_complete "DWL components"
    else
        log_warn "No DWL components found to build"
        mark_failed "DWL components"
    fi
}

# ============================================================================
# GRUB THEME
# ============================================================================
configure_grub() {
    log_info "Configuring GRUB theme..."

    if grep -q "catppuccin-mocha" /etc/default/grub 2>/dev/null; then
        log_success "GRUB already themed"
        mark_complete "GRUB theme"
        return 0
    fi

    local theme_dir="/usr/share/grub/themes/catppuccin-mocha"
    local logo_src="$HOME/dotfiles/de/Documents/logo.png"

    if [[ -d "$theme_dir" ]] && [[ -f "$logo_src" ]]; then
        sudo rm -f "$theme_dir/logo.png"
        sudo cp "$logo_src" "$theme_dir/logo.png"
        echo 'GRUB_THEME="/usr/share/grub/themes/catppuccin-mocha/theme.txt"' | sudo tee -a /etc/default/grub >/dev/null
        sudo grub-mkconfig -o /boot/grub/grub.cfg
        log_success "GRUB themed successfully"
        mark_complete "GRUB theme"
    else
        log_warn "Theme directory or logo not found, skipping"
        mark_failed "GRUB theme"
    fi
}

# ============================================================================
# GREETD DISPLAY MANAGER
# ============================================================================
configure_greetd() {
    log_info "Configuring greetd display manager..."

    if [[ -f /etc/greetd/config.toml ]]; then
        log_success "Greetd already configured"
        mark_complete "Greetd"
        return 0
    fi

    sudo mkdir -p /etc/greetd
    sudo tee /etc/greetd/config.toml >/dev/null <<'EOF'
[terminal]
vt = 1

[default_session]
command = "/usr/bin/tuigreet -r --asterisks -c dwl"
user = "greeter"
EOF

    log_success "Greetd configured"
    mark_complete "Greetd"
}

# ============================================================================
# SWAP FILE
# ============================================================================
setup_swap() {
    log_info "Setting up swap file..."

    if [[ -f /swapfile ]]; then
        log_success "Swap file already exists"
        mark_complete "Swap file"
        return 0
    fi

    log_info "Creating 16GB swap file (this may take a while)..."
    sudo dd if=/dev/zero of=/swapfile bs=1G count=16 status=progress
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile

    if ! grep -q "/swapfile" /etc/fstab; then
        echo "/swapfile none swap defaults 0 0" | sudo tee -a /etc/fstab >/dev/null
    fi

    log_success "Swap file created and enabled"
    mark_complete "Swap file"
}

# ============================================================================
# SHELL CONFIGURATION
# ============================================================================
configure_shell() {
    log_info "Configuring shell environment..."

    # Change default shell to zsh
    if [[ "$SHELL" != "/bin/zsh" ]]; then
        sudo chsh "$USER" -s /bin/zsh
        log_success "Default shell changed to zsh (re-login required)"
    fi

    # Configure zsh environment
    if [[ ! -f /etc/zsh/zshenv ]]; then
        sudo mkdir -p /etc/zsh
        echo "export ZDOTDIR=/home/$USER/.config/zsh" | sudo tee /etc/zsh/zshenv >/dev/null
        log_success "Configured zsh environment"
    fi

    # Replace sh with dash for performance
    if [[ "$(readlink /bin/sh)" != "/bin/dash" ]]; then
        sudo rm -f /bin/sh
        sudo ln -s /bin/dash /bin/sh
        log_success "Replaced /bin/sh with dash"
    fi

    # Install zplug
    if [[ ! -d "$HOME/.local/share/zplug" ]]; then
        git clone https://github.com/zplug/zplug "$HOME/.local/share/zplug"
        log_success "Installed zplug"
    fi

    mark_complete "Shell configuration"
}

# ============================================================================
# ZEN BROWSER
# ============================================================================
configure_zen() {
    log_info "Configuring Zen browser..."

    local profiles_ini="$HOME/.zen/profiles.ini"
    if [[ ! -f "$profiles_ini" ]]; then
        log_warn "Zen browser not set up yet, skipping"
        mark_failed "Zen browser"
        return 1
    fi

    local default_profile=$(grep -A1 '\[Install' "$profiles_ini" | grep '^Default=' | cut -d= -f2-)
    local profile_dir="$HOME/.zen/$default_profile"

    if [[ -n "$default_profile" ]] && [[ -d "$profile_dir" ]]; then
        rm -rf "$profile_dir/chrome" "$profile_dir/user.js"
        ln -s "$HOME/dotfiles/de/.zen/chrome" "$profile_dir/chrome"
        ln -s "$HOME/dotfiles/de/.zen/user.js" "$profile_dir/user.js"
        xdg-settings set default-web-browser zen.desktop 2>/dev/null || true
        log_success "Zen browser configured"
        mark_complete "Zen browser"
    else
        log_warn "Could not find Zen profile directory"
        mark_failed "Zen browser"
    fi
}

# ============================================================================
# DOOM EMACS
# ============================================================================
install_doom_emacs() {
    log_info "Installing Doom Emacs..."

    if [[ -d "$HOME/.config/emacs" ]]; then
        log_success "Doom Emacs already installed"
        mark_complete "Doom Emacs"
        return 0
    fi

    git clone --depth 1 https://github.com/doomemacs/doomemacs "$HOME/.config/emacs"
    "$HOME/.config/emacs/bin/doom" install --force

    log_success "Doom Emacs installed"
    mark_complete "Doom Emacs"
}

# ============================================================================
# TMUX PLUGIN MANAGER
# ============================================================================
install_tpm() {
    log_info "Installing tmux plugin manager..."

    local tpm_dir="$HOME/.local/share/tmux/plugins/tpm"
    if [[ -d "$tpm_dir" ]]; then
        log_success "TPM already installed"
        mark_complete "Tmux plugin manager"
        return 0
    fi

    git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
    log_success "TPM installed"
    mark_complete "Tmux plugin manager"
}

# ============================================================================
# SYSTEMD SERVICES
# ============================================================================
configure_services() {
    log_info "Configuring systemd services..."

    # Create MPD directory
    mkdir -p "$HOME/.local/share/mpd"

    # User services
    local user_services=(mpd mpdris xdg-desktop-portal)
    for service in "${user_services[@]}"; do
        systemctl --user enable --now "$service" 2>/dev/null || true
    done

    # System services
    local system_services=(ufw bluetooth dbus udisks2 greetd)
    for service in "${system_services[@]}"; do
        sudo systemctl enable "$service" 2>/dev/null || true
        if [[ "$service" != "greetd" ]]; then
            sudo systemctl start "$service" 2>/dev/null || true
        fi
    done

    # Enable firewall
    sudo ufw --force enable 2>/dev/null || true

    log_success "Services configured"
    mark_complete "Systemd services"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================
print_banner() {
    echo -e "${BLUE}"
    echo "═══════════════════════════════════════════════════════"
    echo "  Arch Linux Dotfiles Installation Script"
    echo "═══════════════════════════════════════════════════════"
    echo -e "${NC}"
}

print_summary() {
    echo
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Installation Summary${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo

    if ((${#COMPLETED_STEPS[@]} > 0)); then
        echo -e "${GREEN}Completed:${NC}"
        for step in "${COMPLETED_STEPS[@]}"; do
            echo -e "  ${GREEN}✓${NC} $step"
        done
    fi

    if ((${#FAILED_STEPS[@]} > 0)); then
        echo
        echo -e "${YELLOW}Skipped/Failed:${NC}"
        for step in "${FAILED_STEPS[@]}"; do
            echo -e "  ${YELLOW}✗${NC} $step"
        done
    fi

    echo
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Installation complete!${NC}"
    echo
    echo -e "${YELLOW}Important:${NC}"
    echo "  • Log out and log back in for group changes to take effect"
    echo "  • Run 'tmux' and press prefix + I to install tmux plugins"
    echo "  • Run 'nvim' and let plugins install automatically"
    echo "  • Reboot to start using greetd display manager"
    echo
}

main() {
    print_banner

    # Run all setup functions
    setup_groups
    configure_pacman
    install_system_packages
    install_paru
    install_aur_packages
    build_dwl
    configure_grub
    configure_greetd
    setup_swap
    configure_shell
    configure_zen
    install_doom_emacs
    install_tpm
    configure_services

    print_summary
}

# Run main function
main "$@"
