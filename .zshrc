# Ensure Nix profile bins come first
if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi
export PATH="$HOME/.nix-profile/bin:$PATH"

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Fix for corrupted history file
if [[ ! -w ~/.zsh_history ]]; then
  rm ~/.zsh_history
  touch ~/.zsh_history
fi

# History configuration
HISTSIZE=2000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# Aliases
alias ls='ls --color'

# Shell integrations
eval "$(fzf --zsh)"
eval "$(zoxide init --cmd cd zsh)"

# GPG configuration
export GPG_TTY=$(tty)
gpgconf --kill gpg-agent 2>/dev/null

# Zoxide initialization
eval "$(zoxide init zsh)"

# Oh My Zsh installation path (if using it)
# export ZSH="$HOME/.oh-my-zsh"

# Add Zinit for plugin management
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

# Zinit plugins
zinit ice depth=1; zinit light romkatv/powerlevel10k
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
ZSH_AUTOSUGGEST_USE_ASYNC=1

# Load Completions
autoload -Uz compinit
if [[ -n ${ZDOTDIR}/.zcompdump(#qNmh+24) ]]; then
  compinit
else
  compinit -C
fi

# Load Powerlevel10k configuration
[[ ! -f ~/.config/nix/.p10k.zsh ]] || source ~/.config/nix/.p10k.zsh

# Keybindings
bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
bindkey '^[w' kill-region

# Enable auto-correction and completion dots
ENABLE_CORRECTION="true"
COMPLETION_WAITING_DOTS="true"

# Zsh prompt initialization
autoload -Uz promptinit
promptinit
prompt adam1

# Disable auto-update notifications (optional)
# zstyle ':omz:update' mode disabled

# Case-insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# To suppress Powerlevel10k warnings, use:
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

(( ! ${+functions[p10k]} )) || p10k finalize
typeset -g POWERLEVEL9K_INSTANT_PROMPT=off

# Go environment variables
export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"

