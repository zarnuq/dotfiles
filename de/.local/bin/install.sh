#!/bin/sh
#groups
sudo usermod -a -G mpd,power,video,storage,kvm,disk,audio $USER



#needed packages
echo "[options]
Color
[multilib]
Include = /etc/pacman.d/mirrorlist" | sudo tee -a /etc/pacman.conf
sudo pacman -Syu --noconfirm
sudo pacman -S --noconfirm base-devel yazi stow rmpc mpd easyeffects neovim kitty wezterm fastfetch river rofi-wayland zsh pavucontrol zathura hyprland gammastep wtype nemo brightnessctl swaybg wlr-randr vlc mpv github-cli git fd fzf zoxide tree vim btop dunst ufw udisks2 qt6-svg qt6-declarative qt5-quickcontrols2 greetd greetd-tuigreet ttf-font-awesome otf-font-awesome ttf-jetbrains-mono-nerd papirus-icon-theme adwaita-fonts adwaita-cursors adw-gtk-theme grim slurp xdg-desktop-portal xdg-desktop-portal-wlr dash nwg-look swaylock man-db tmux xremap-wlroots-bin 7zip steam lsp-plugins bluez blueberry
sudo rm /usr/share/applications/in.lsp_plug.lsp_plugins_*
echo "arch repo packages installed"



#paru
git clone https://aur.archlinux.org/paru.git ~/paru
cd ~/paru
makepkg -si
cd ~
rm -rf ~/paru
echo "BottomUp" | sudo tee -a /etc/paru.conf
echo "paru installed"



#paru packages
paru -S zen-browser-bin brave-bin mpdris vscodium xremap catppuccin-sddm-theme-mocha yambar catppuccin-gtk-theme-mocha bibata-cursor-theme legcord pscircle
echo "AUR packages added"



#change shell
sudo chsh "$USER" -s /bin/zsh
sudo mkdir /etc/zsh
echo "export ZDOTDIR=/home/miles/.config/zsh" | sudo tee /etc/zsh/zshenv
sudo rm /bin/sh
sudo ln -s /bin/dash /bin/sh
git clone https://github.com/zplug/zplug ~/.local/share
echo "shell changed"



#swap
if [ ! -f "/swapfile" ]; then
    sudo dd if=/dev/zero of=/swapfile bs=1G count=16 status=progress
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo "/swapfile none swap defaults 0 0" | sudo tee -a /etc/fstab
    echo "swapfile created"
fi



#greetd
sudo mkdir /etc/greetd
sudo tee /etc/greetd/config.toml > /dev/null <<'EOF'
[terminal]
vt = 1

[default_session]
command = "/usr/bin/tuigreet -r -c river"
user = "greeter"
EOF
echo "greetd configured"



#services
mkdir ~/.local/share/mpd
systemctl --user enable --now mpd
systemctl --user enable --now mpdris
systemctl --user enable --now xdg-desktop-portal 
systemctl --user enable --now xdg-desktop-portal-wlr
sudo systemctl enable --now ufw
sudo systemctl enable --now dbus 
sudo systemctl enable --now udisks2 
sudo systemctl enable greetd
sudo ufw enable
echo "services started"

