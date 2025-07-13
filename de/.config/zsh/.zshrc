#VI MODE
stty -ixon
bindkey -v
export KEYTIMEOUT=1
function zle-keymap-select {
  case $KEYMAP in
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
alias pfzf='paru -Slaq | fzf '
alias gs='git status -s'
alias gac='git add .; git commit -m'
alias gp='git push'
alias ip='ip -c'
alias vim='nvim'
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias nord='sudo systemctl start nordvpnd && nordvpn c Chicago'
alias cd='z'
alias ka='killall'
alias rebuild='sudo nixos-rebuild switch --flake /home/miles/dotfiles/nixos/ --impure'
alias nixdir='sudo -E yazi /etc/nixos'
alias pickcolor='grim -g "$(slurp -p)" -t ppm - | convert - -format "%[pixel:p{0,0}]" txt:-'
alias zshrc='nvim $ZDOTDIR/.zshrc'
alias bkmrk='nvim $XDG_CONFIG_HOME/scripts/bkmrk.txt'
alias r='river'
alias ff='fastfetch'

#CONFIG
export EDITOR=nvim
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

# Declare plugins
zplug "zsh-users/zsh-syntax-highlighting"
zplug "zsh-users/zsh-autosuggestions"
zplug "Aloxaf/fzf-tab"
if ! zplug check --verbose; then
    zplug install
fi
zplug load


export ZSH_AUTOCOMPLETE_WIDGET_ASYNC="true"
eval "$(zoxide init zsh)"
eval "$(starship init zsh)"
eval "$(fzf --zsh)"
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git "
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
