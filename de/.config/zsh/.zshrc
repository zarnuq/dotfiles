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
alias code='vscodium'
alias ka='killall'
alias rebuild='sudo nixos-rebuild switch --flake /home/miles/dotfiles/nixos/ --impure'
alias nixdir='sudo -E yazi /etc/nixos'
alias pickcolor='grim -g "$(slurp -p)" -t ppm - | convert - -format "%[pixel:p{0,0}]" txt:-'
alias zshrc='nvim $ZDOTDIR/.zshrc'
alias bkmrk='nvim $XDG_CONFIG_HOME/scripts/bkmrk.txt'
alias r='river'

#CONFIG
export EDITOR=nvim
_comp_options+=(globdots)
HYPHEN_INSENSITIVE="true"
HIST_STAMPS="mm/dd/yyyy"
HISTFILE=$ZDOTDIR/zsh_history
HISTSIZE=100000
SAVEHIST=100000
HISTCONTROL="ignoredups:erasedups"
HISTIGNORE="ls:cd:pwd:exit"
setopt prompt_subst
source ~/.local/share/zplug/repos/agnoster/agnoster-zsh-theme/agnoster.zsh-theme
precmd() { print "" }

#PLUGINS
source $ZPLUG_HOME/init.zsh
zplug "agnoster/agnoster-zsh-theme"
zplug "zsh-users/zsh-syntax-highlighting"
zplug "zsh-users/zsh-autosuggestions"
zplug "Aloxaf/fzf-tab"

if ! zplug check --verbose; then
    zplug install
fi
zplug load

#AUTOSUGGESTIONS/COMPLETIONS
export ZSH_AUTOCOMPLETE_WIDGET_ASYNC="true"

#ZOXIDE
eval "$(zoxide init zsh)"

#FZF STUFF
eval "$(fzf --zsh)"
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git "
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"


fastfetch 
