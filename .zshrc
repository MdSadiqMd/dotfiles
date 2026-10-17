# ASCII BOAT SHELL INTEGRATION START boat
case ":$PATH:" in
  *":/Users/sadiq/.ascii/bin:"*) ;;
  *) PATH="/Users/sadiq/.ascii/bin:$PATH" ;;
esac
export PATH
# ASCII BOAT SHELL INTEGRATION END boat

# Ensure Nix profile bins come first
if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi
export PATH="$HOME/.nix-profile/bin:$PATH"
export PATH="$HOME/.avm/bin:$HOME/.cargo/bin:$HOME/.local/share/solana/install/active_release/bin:$PATH"

function git_status_counts() {
  local git_status=$(git status --porcelain=v2 2>/dev/null)
  if [[ -n "$git_status" ]]; then
    local added=$(echo "$git_status" | grep '^A\|^??' | wc -l | tr -d ' ')
    local modified=$(echo "$git_status" | grep -E '^( |M|D|R)' | wc -l | tr -d ' ')
    
    local git_info=""
    [[ $added -gt 0 ]] && git_info+="%F{green}+${added}%f"
    [[ $modified -gt 0 ]] && git_info+=" %F{yellow}~${modified}%f"
    
    echo "${git_info}"
  fi
}

if command -v xcrun >/dev/null; then
  export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
  export LIBRARY_PATH="$SDKROOT/usr/lib:$LIBRARY_PATH"
  export CPATH="$SDKROOT/usr/include:$CPATH"
fi

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
alias clear='clear && clear'

# Shell integrations
eval "$(fzf --zsh)"
eval "$(zoxide init --cmd cd zsh)"

# GPG configuration
export GPG_TTY=$(tty)
gpgconf --kill gpg-agent 2>/dev/null
gpgconf --launch gpg-agent

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
# prompt adam1

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


# bun completions
[ -s "/Users/sadiq/.bun/_bun" ] && source "/Users/sadiq/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export PATH="$HOME/.npm-global/bin:$PATH"

# Added by Antigravity
export PATH="/Users/sadiq/.antigravity/antigravity/bin:$PATH"
export PATH="/Users/sadiq/.local/bin:$PATH"

# Solana
PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

# Generated for envman. Do not edit.
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"

# Added by Antigravity
export PATH="/Users/sadiq/.antigravity/antigravity/bin:$PATH"

export NARGO_HOME="/Users/sadiq/.nargo"

export PATH="$PATH:$NARGO_HOME/bin"

# Added by Antigravity
export PATH="/Users/sadiq/.antigravity/antigravity/bin:$PATH"

# Added by Antigravity
export PATH="/Users/sadiq/.antigravity/antigravity/bin:$PATH"

# Added by Antigravity
export PATH="/Users/sadiq/.antigravity/antigravity/bin:$PATH"

# Added by Antigravity
export PATH="/Users/sadiq/.antigravity/antigravity/bin:$PATH"

# Added by Antigravity
export PATH="/Users/sadiq/.antigravity/antigravity/bin:$PATH"

# Added by Antigravity
export PATH="/Users/sadiq/.antigravity/antigravity/bin:$PATH"

# Mesh compiler
. "/Users/sadiq/.mesh/env"

# Added by Antigravity
export PATH="/Users/sadiq/.antigravity/antigravity/bin:$PATH"

# Added by Antigravity
export PATH="/Users/sadiq/.antigravity/antigravity/bin:$PATH"
export LLVM_SYS_211_PREFIX="$(brew --prefix llvm@21)"
export MESHER_MESHC_BIN="$HOME/Developer/mesh-lang/target/debug/meshc"
export MESHER_MESHC_SOURCE="$HOME/Developer/mesh-lang"

# opencode
export PATH=/Users/sadiq/.opencode/bin:$PATH

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

. "$HOME/.local/bin/env"

export PATH="$PATH:/Users/sadiq/.risc0/bin"
export PATH="$PATH:/Applications/Tailscale.app/Contents/MacOS/Tailscale status"






# ponytail: tmux is RAM-only, so reboot wipes sessions; recreate lazily on first
# shell (continuum auto-restore runs on server start when a save exists, script
# is idempotent fallback). Upgrade to a launchd agent if you need sessions
# before opening any terminal.
if command -v tmux >/dev/null 2>&1 && [[ -z "$TMUX" ]]; then
  { tmux has-session -t todo 2>/dev/null || tmux has-session -t dognosis 2>/dev/null || /Users/sadiq/.config/nix/tmux-sessions.sh >/dev/null 2>&1; } &!
fi

# ASCII BOAT SHELL INTEGRATION START boat
boat() {
  current_file=$(mktemp)
  convo_file=$(mktemp)
  old_current_file=${BOAT_CURRENT_ID_FILE-}
  old_convo_file=${BOAT_CURRENT_CONVO_FILE-}
  export BOAT_CURRENT_ID_FILE="$current_file"
  export BOAT_CURRENT_CONVO_FILE="$convo_file"
  command "/Users/sadiq/.ascii/bin/boat" "$@"
  boat_status=$?
  if [ "$boat_status" -eq 0 ]; then
    case "${1:-}" in
      new|start|fork)
        if [ -s "$current_file" ]; then
          current_id=$(tr -d '[:space:]' < "$current_file")
          if [ -n "$current_id" ]; then export BOAT_CURRENT_ID="$current_id"; fi
        fi
        ;;
    esac
    case "${1:-}" in
      prompt)
        if [ -s "$convo_file" ]; then
          IFS= read -r current_convo < "$convo_file" || current_convo=""
          if [ -n "$current_convo" ]; then export BOAT_CURRENT_CONVO="$current_convo"; fi
        fi
        ;;
    esac
  fi
  if [ -n "$old_current_file" ]; then export BOAT_CURRENT_ID_FILE="$old_current_file"; else unset BOAT_CURRENT_ID_FILE; fi
  if [ -n "$old_convo_file" ]; then export BOAT_CURRENT_CONVO_FILE="$old_convo_file"; else unset BOAT_CURRENT_CONVO_FILE; fi
  rm -f "$current_file" "$convo_file"
  return "$boat_status"
}
# ASCII BOAT SHELL INTEGRATION END boat





. "/Users/sadiq/.local/bin/watcher-env"
