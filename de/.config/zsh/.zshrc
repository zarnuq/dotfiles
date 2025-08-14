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
alias r='river'
alias ff='fastfetch'
alias doomsync='pkill emacs;systemctl --user stop emacs;doom sync;systemctl --user start emacs'

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

# Declare plugins
zplug "zsh-users/zsh-syntax-highlighting"
zplug "zsh-users/zsh-autosuggestions"
zplug "Aloxaf/fzf-tab"
if ! zplug check --verbose; then
    zplug install
fi
zplug load

# Add this to your ~/.zshrc file

# Add this to your ~/.zshrc file

# Enable parameter expansion, command substitution and arithmetic expansion in prompts
setopt PROMPT_SUBST

# Enable colors
autoload -U colors && colors

# Function to get git branch
git_branch() {
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null)
    if [[ -n $branch ]]; then
        echo " %{$fg[cyan]%}($branch%{$reset_color%}"
    fi
}

# Function to get git status
git_status() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        local git_st=""
        
        # Check for uncommitted changes
        if ! git diff --quiet 2>/dev/null; then
            git_st="${git_st}%{$fg[red]%}*%{$reset_color%}"
        fi
        
        # Check for staged changes
        if ! git diff --cached --quiet 2>/dev/null; then
            git_st="${git_st}%{$fg[green]%}+%{$reset_color%}"
        fi
        
        # Check for untracked files
        if [[ -n $(git ls-files --others --exclude-standard 2>/dev/null) ]]; then
            git_st="${git_st}%{$fg[yellow]%}?%{$reset_color%}"
        fi
        
        if [[ -n $git_st ]]; then
            echo "$git_st%{$fg[cyan]%})%{$reset_color%}"
        else
            echo "%{$fg[cyan]%})%{$reset_color%}"
        fi
    fi
}

# Set the prompt
PROMPT='%{$fg[blue]%}%~%{$reset_color%}$(git_branch)$(git_status) %{$fg[white]%}$%{$reset_color%} '
export ZSH_AUTOCOMPLETE_WIDGET_ASYNC="true"
#eval "$(zoxide init zsh)"
#eval "$(starship init zsh)"
eval "$(fzf --zsh)"
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git "
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
