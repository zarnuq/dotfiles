#VI MODE
stty -ixon
bindkey -v
export KEYTIMEOUT=1
function zle-keymap-select { case $KEYMAP in
    vicmd) echo -ne '\e[2 q' ;;  # Block cursor in Normal mode
    viins|main) echo -ne '\e[6 q' ;;  # Beam cursor in Insert mode
  esac
}
zle -N zle-keymap-select
function zle-line-init {
  echo -ne '\e[6 q'  # Set cursor to beam on shell start
}
zle -N zle-line-init
echo -ne '\e[6 q'  # Ensure cursor is reset when shell starts

#ALIASES
alias y='yazi'
alias p='paru'
alias gs='git status -s'
alias gac='git add .; git commit -m'
alias gp='git push'
alias ip='ip -c'
alias vim='nvim'
alias ls='ls --color=auto'
alias ll='ls -l --color=auto'
alias grep='grep --color=auto'
alias nord='sudo systemctl start nordvpnd && nordvpn c Chicago'
alias ka='killall'
alias pickcolor='grim -g "$(slurp -p)" -t ppm - | convert - -format "%[pixel:p{0,0}]" txt:-'
alias zshrc='nvim $ZDOTDIR/.zshrc'
alias bkmrk='nvim $XDG_CONFIG_HOME/scripts/bkmrk.txt'
alias ff='fastfetch'
alias doomsync='pkill emacs;systemctl --user stop emacs;doom sync;systemctl --user start emacs'
alias ta='tmux attach-session -t'

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

SPACESHIP_PROMPT_ORDER=(
  dir            # Current directory section
  git            # Git section (git_branch + git_status)
  exec_time      # Execution time
  exit_code      # Exit code section
  char           # Prompt character
)
SPACESHIP_CHAR_SYMBOL="> "
SPACESHIP_CHAR_SYMBOL_FAILURE="x "
SPACESHIP_CHAR_COLOR_SUCCESS="white"
SPACESHIP_DIR_TRUNC_REPO="false"
SPACESHIP_DIR_LOCK_SYMBOL=""
SPACESHIP_GIT_PREFIX=""
SPACESHIP_GIT_BRANCH_PREFIX=""
SPACESHIP_GIT_STATUS_PREFIX=""
SPACESHIP_GIT_STATUS_SUFFIX=""

# Declare plugins
zplug "zsh-users/zsh-syntax-highlighting"
zplug "zsh-users/zsh-autosuggestions"
zplug "Aloxaf/fzf-tab"
zplug "spaceship-prompt/spaceship-prompt"
if ! zplug check --verbose; then
    zplug install
fi
zplug load

export MANPAGER="nvim +Man!"
export ZSH_AUTOCOMPLETE_WIDGET_ASYNC="true"
eval "$(fzf --zsh)"
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git "
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
