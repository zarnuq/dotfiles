export PATH=/usr/bin:/usr/sbin:/bin:/sbin:$HOME/.local/bin:/usr/local/bin:$HOME/.config/emacs/bin:/nix/var/nix/profiles/default/bin:$HOME/.nix-profile/bin
# /etc/zsh/zshenv sources nix-daemon.sh (which sets __ETC_PROFILE_NIX_SOURCED=1
# and adds nix to PATH). Then /etc/zsh/zprofile sources /etc/profile.env, whose
# baselayout `export PATH=...` wipes nix out — and the nix.sh re-run later in
# zprofile self-skips because that guard var is still set. Clearing it here lets
# nix-daemon.sh actually re-run during zprofile and re-prepend nix AFTER the
# baselayout reset, so nix survives in login shells (tmux, ttys).
unset __ETC_PROFILE_NIX_SOURCED
export XDG_CACHE_HOME=$HOME/.cache
export XDG_CONFIG_HOME=$HOME/.config
export XDG_DATA_HOME=$HOME/.local/share
export XDG_STATE_HOME=$HOME/.local/state
export ZDOTDIR=$XDG_CONFIG_HOME/zsh
export EDITOR=nvim
export ZPLUG_HOME=$XDG_DATA_HOME/zplug
export PULSE_COOKIE=$XDG_CONFIG_HOME/pulse/cookie
