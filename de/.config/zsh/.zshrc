export XDG_RUNTIME_DIR="/run/user/$(id -u)"
if [[ ! -f $HOME/.local/share/zplug/init.zsh ]]; then
    curl -sL --proto-redir -all,https \
        https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh
fi
source $ZPLUG_HOME/init.zsh

#ALIASES
alias wget='wget --hsts-file="$XDG_DATA_HOME/wget-hsts"'
alias gs='git status -s'
alias gac='git add .; git commit -m'
alias gp='git push'
alias ip='ip -c'
alias vim='emacs -nw'
alias ls='ls --color=auto'
alias ll='ls -l --color=auto'
alias grep='grep --color=auto'
alias pickcolor='grim -g "$(slurp -p)" -t ppm - | convert - -format "%[pixel:p{0,0}]" txt:-'
alias zshrc='nvim $ZDOTDIR/.zshrc'
alias ff='fastfetch'
alias doomsync='~/.config/emacs/bin/doom sync'
alias ta='tmux attach-session -t'
alias esync='sudo emerge --sync'
alias eworld='sudo emerge -avuDN @world'
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
HYPHEN_INSENSITIVE="true"
HIST_STAMPS="mm/dd/yyyy"
HISTFILE=$ZDOTDIR/zsh_history
HISTSIZE=1000000
SAVEHIST=1000000
HISTCONTROL="ignoredups:erasedups"
HISTIGNORE="ls:cd:pwd:exit"

#PLUGINS
source $ZPLUG_HOME/init.zsh

# Pure prompt (replaces spaceship): dir + git on the left, exec time inline, clock on the right
PURE_CMD_MAX_EXEC_TIME=0          # always show last command's exec time (was SPACESHIP_EXEC_TIME_ELAPSED=0)
PURE_PROMPT_SYMBOL=' >'           # 1-space left buffer + symbol (was SPACESHIP_CHAR_SYMBOL="> ")
PURE_PROMPT_VICMD_SYMBOL=' >'
PURE_GIT_PULL=0                   # skip background git fetch (faster/minimal)
zstyle :prompt:pure:path            color '#89b4fa'   # dir (blue)
zstyle :prompt:pure:git:branch      color '#cba6f7'   # git branch (mauve accent)
zstyle :prompt:pure:git:dirty       color '#f9e2af'   # dirty marker (yellow)
zstyle :prompt:pure:execution_time  color '#fab387'   # exec time (peach)
zstyle :prompt:pure:prompt:success  color '#a6e3a1'   # prompt > on success (green)
zstyle :prompt:pure:prompt:error    color '#f38ba8'   # prompt > on error (red)

# Declare plugins
zplug "zsh-users/zsh-syntax-highlighting"
zplug "zsh-users/zsh-autosuggestions"
zplug "jeffreytse/zsh-vi-mode"
zplug "mafredri/zsh-async", from:github
zplug "sindresorhus/pure", use:pure.zsh, from:github, as:theme
if ! zplug check --verbose; then
    zplug install
fi
zplug load

PROMPT=' '$PROMPT                      # 1-space left buffer on the dir/git preprompt line (matches PURE_PROMPT_SYMBOL)
RPROMPT='%F{#6c7086}%D{%H:%M:%S}%f'   # clock on the right (was SPACESHIP time)

export MANPAGER="nvim +Man!"
export ZSH_AUTOCOMPLETE_WIDGET_ASYNC="true"
eval "$(fzf --zsh)"
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
export TERM=xterm-256color
