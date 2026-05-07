# Set up the prompt
PS1='%(?.%F{darkgreen}.%F{red})[%1~]$%b%f '

CASE_INSENSITIVE="true"

setopt histignorealldups sharehistory
setopt MENU_COMPLETE
setopt no_list_ambiguous

bindkey -v

# --- ADD THESE LINES ---
export KEYTIMEOUT=1                  # Reduces the Escape delay to 10ms (instant)
bindkey -M viins '^[' vi-cmd-mode    # Explicitly maps Ctrl-[ / Esc to normal mode
# -----------------------

alias aud='/home/saifr/progs/audacity-linux-3.6.1-x64.AppImage'
alias slidesetter="libreoffice --accept=\"socket,host=localhost,port=2002;urp;\""
alias ls="ls -F"
alias sl="ls -F"
alias gdb="gdb --silent"

HISTSIZE=1000
SAVEHIST=1000
HISTFILE=~/.zsh_history

autoload -Uz compinit
compinit


bindkey "^P" reverse-menu-complete
zstyle ':completion:*' menu yes select
zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete _correct _approximate
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'r:|[._-]=* r:|=* l:|=*' 'm:{A-Z}={a-z}'
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'
alias c="cd"

export ASAN_SYMBOLIZER_PATH=/usr/bin/llvm-symbolizer
unsetopt BEEP
