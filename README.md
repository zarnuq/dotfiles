# My dotfiles
### configured applications
* btop
* dunst
* dwl
* dwlb
* easyeffects(eq)
* doom emacs
* fastfetch
* ghostty
* ghostwriter
* gtk themes
* hypr(land,paper,idle,lock)
* kitty
* kvantum
* legcord
* mpd
* nvim
* pipewire settings
* qBittorrent
* qt themes
* river
* rmpc
* rofi
* swaylock
* swaybg
* swww
* tidal_dl_ng
* tmux
* tridactyl
* waybar
* wezterm
* xremap
* yambar
* yazi
* zen-browser theme
* zsh (spaceship, zplug)

## My Custom DWL Repo
#### included patches
* autostart (adds autostart section in config.h)
* warpcursor (warps cursor to active window and monitor)
* cursortheme (<-)
* monitorconfig (adds more parameters for monitors such as refresh rate)
* ipc (for dwlb)
* centerfloating (new floating windows center to monitor)
* tmuxborder (only show borders for a window when touching another window and when it is focused)
* moveresizekb  (keybinds for moving and resizing a floating window)
* switchtotag (adds rule to switch to tag on window open and switch back on close)
* regexrules (adds regex rules to dwl rules)
* keepontag (very simple patch i made to keep windows on the same tags when moved between monitors, also makes you switch view to that tag but without focus)
* keychords (adds functionallity for multikey combo like "mod+r" then "t" for opening terminal like in emacs )

## Install
```
cd ~
git clone https://github.com/zarnuq/dotfiles.git
cd dotfiles
stow de
install.sh
```
