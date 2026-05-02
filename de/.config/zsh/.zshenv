# XDG base dirs — needed here so zsh itself and ZDOTDIR resolve correctly
export XDG_CACHE_HOME=$HOME/.cache
export XDG_CONFIG_HOME=$HOME/.config
export XDG_DATA_HOME=$HOME/.local/share
export XDG_STATE_HOME=$HOME/.local/state
# Must be in zshenv so zsh finds its config dir early
export ZDOTDIR=$XDG_CONFIG_HOME/zsh
# PATH — shell specific
export PATH="/usr/bin:/usr/sbin:/bin:/sbin:$HOME/.local/bin:/usr/local/bin:$HOME/.config/emacs/bin:/nix/var/nix/profiles/default/bin:$HOME/.nix-profile/bin"
# Shell editor
export EDITOR=nvim
# zplug — shell plugin manager
export ZPLUG_HOME=$XDG_DATA_HOME/zplug
# pulse cookie — audio, may be needed before GUI but keep here as fallback
export PULSE_COOKIE=$XDG_CONFIG_HOME/pulse/cookie
