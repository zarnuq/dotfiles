#!/bin/bash
#groups
group_list=(mpd power video storage kvm disk audio)
for group in "${group_list[@]}"; do
  if ! groups "$USER" | grep -qw "$group"; then
    sudo usermod -a -G "$group" "$USER"
  fi
done
echo "groups added"


#needed packages
sudo pacman -Syu --noconfirm
if ! grep -Fxq "[multilib]" /etc/pacman.conf; then
  echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | sudo tee -a /etc/pacman.conf
fi

if ! grep -Fxq "Color" /etc/pacman.conf; then
  echo -e "\n[options]\nColor" | sudo tee -a /etc/pacman.conf
fi
packages=(base-devel yazi stow rmpc mpd easyeffects neovim kitty wezterm fastfetch river rofi-wayland zsh pavucontrol zathura hyprland gammastep wtype nemo brightnessctl swaybg wlr-randr vlc mpv github-cli git fd fzf zoxide tree vim btop dunst ufw udisks2 greetd greetd-tuigreet ttf-font-awesome otf-font-awesome ttf-jetbrains-mono-nerd papirus-icon-theme adwaita-fonts adwaita-cursors adw-gtk-theme grim slurp xdg-desktop-portal xdg-desktop-portal-wlr dash nwg-look swaylock man-db tmux 7zip steam lsp-plugins bluez blueberry glow starship imagemagick noto-fonts-emoji loupe tldr playerctl qbittorrent qt6ct ghostwriter)
missing_pkgs=()
for pkg in "${packages[@]}"; do
  pacman -Qq "$pkg" &>/dev/null || missing_pkgs+=("$pkg")
done
if (( ${#missing_pkgs[@]} )); then
  sudo pacman -S --noconfirm "${missing_pkgs[@]}"
fi
tldr --update
sudo rm /usr/share/applications/in.lsp_plug.lsp_plugins_*
echo "arch repo packages installed"



#paru
if ! command -v paru &>/dev/null; then
  git clone https://aur.archlinux.org/paru.git ~/paru
  (cd ~/paru && makepkg -si --noconfirm)
  rm -rf ~/paru
  echo "BottomUp" | sudo tee -a /etc/paru.conf
fi
echo "paru installed"



#paru packages
aur_packages=(zen-browser-bin brave-bin mpdris-bin xremap-wlroots-bin yambar catppuccin-mocha-grub-theme-git catppuccin-gtk-theme-mocha bibata-cursor-theme legcord pscircle kvantum-theme-catppuccin-git)
for pkg in "${aur_packages[@]}"; do
  paru -Qq "$pkg" &>/dev/null || paru -S --noconfirm "$pkg"
done
echo "AUR pkgs added"


#grub
if ! grep "catppuccin-mocha" /etc/default/grub; then
  sudo rm /usr/share/grub/themes/catppuccin-mocha/logo.png
  sudo cp ~/Documents/logo.png /usr/share/grub/themes/catppuccin-mocha
  echo 'GRUB_THEME="/usr/share/grub/themes/catppuccin-mocha/theme.txt"' | sudo tee -a /etc/default/grub
  sudo grub-mkconfig -o /boot/grub/grub.cfg
  echo "grub themed"
else
  echo "grub already themed"
fi




#change shell
if [ "$SHELL" != "/bin/zsh" ]; then
  sudo chsh "$USER" -s /bin/zsh
fi

if [ ! -f /etc/zsh/zshenv ]; then
  sudo mkdir -p /etc/zsh
  echo "export ZDOTDIR=/home/$USER/.config/zsh" | sudo tee /etc/zsh/zshenv
fi
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
    echo "swap made"
else 
  echo "swap already made"
fi



#greetd
if [ ! -f /etc/greetd/config.toml ]; then
  sudo mkdir /etc/greetd
  sudo tee /etc/greetd/config.toml > /dev/null <<EOF
[terminal]
vt = 1

[default_session]
command = "/usr/bin/tuigreet -r --asterisks -c river"
user = "greeter"
EOF
  echo "greetd configured"
else
  echo "greetd already configured"
fi


#services
mkdir ~/.local/share/mpd
systemctl --user enable --now mpd
systemctl --user enable --now mpdris
systemctl --user enable --now xdg-desktop-portal 
systemctl --user enable --now xdg-desktop-portal-wlr
sudo systemctl enable --now ufw
sudo systemctl enable --now bluetooth 
sudo systemctl enable --now dbus 
sudo systemctl enable --now udisks2 
sudo systemctl enable greetd
sudo ufw enable
echo "services started"

