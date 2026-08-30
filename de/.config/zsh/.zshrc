export XDG_RUNTIME_DIR="/run/user/$(id -u)"
#ALIASES
alias wget='wget --hsts-file="$XDG_DATA_HOME/wget-hsts"'
alias gs='git status -s'
alias gac='git add .; git commit -m'
alias gp='git push'
alias gl='git pull'
alias ip='ip -c'
alias vim='emacs -nw'
alias ls='ls --color=auto'
alias ll='ls -l --color=auto'
alias grep='grep --color=auto'
alias pickcolor='grim -g "$(slurp -p)" -t ppm - | convert - -format "%[pixel:p{0,0}]" txt:-'
alias zshrc='nvim $ZDOTDIR/.zshrc'
alias ff='fastfetch'
alias larp='fastfetch'
alias doomsync='~/.config/emacs/bin/doom sync'
alias ta='tmux attach-session -t'
alias esync='sudo emerge --sync'
alias eworld='sudo emerge -avuDN @world'
alias nixup='nix flake update --flake ~/.config/home-manager && home-manager switch --flake ~/.config/home-manager#miles'
alias nixgc='nix-collect-garbage -d && nix store optimise'
alias pyserver='python -m http.server'
alias c='claude'
alias :q='exit'
function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

#CONFIG
_comp_options+=(globdots)
HISTFILE=$ZDOTDIR/zsh_history
HISTSIZE=1000000
SAVEHIST=1000000
setopt INC_APPEND_HISTORY

#PLUGINS
if [[ ! -f $HOME/.local/share/zplug/init.zsh ]]; then
    curl -sL --proto-redir -all,https \
        https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh
fi
source $ZPLUG_HOME/init.zsh
zplug "jeffreytse/zsh-vi-mode"
zstyle ':zhimmer:*' sources history alias command file git-branch zoxide
zstyle ':zhimmer:*' prompt yes
# menu-style is gone: zhimmer draws the drop-down itself and complist is no
# longer a backend for it, so this setting no longer exists (2026-08-30).
# zstyle ':zhimmer:*' menu-style zle
zplug "/home/miles/zhimmer", from:local, use:"zhimmer.plugin.zsh", defer:2
zplug "zsh-users/zsh-syntax-highlighting"
if ! zplug check --verbose; then
    zplug install
fi
zplug load

HISTORY_IGNORE='(ls|cd|pwd|exit)'
RPROMPT='%F{#6c7086}%D{%H:%M:%S}%f'
export MANPAGER="nvim +Man!"
# fzf binds Ctrl+R in four keymaps, so removing it from the current one alone
# left it reachable: Esc to cancel a search drops into vi normal mode, where
# vicmd still had fzf's widget. zhimmer takes over emacs and viins itself;
# vicmd goes back to `redo`, which is what fzf took it from.
bindkey -r '^R'
bindkey -M emacs -r '^R'
bindkey -M viins -r '^R'
bindkey -M vicmd '^R' redo

