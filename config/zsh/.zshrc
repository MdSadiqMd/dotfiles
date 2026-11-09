# p10k instant prompt: keep first, nothing above may print.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

typeset -U path PATH
[[ -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]] && . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
for f in /etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh $HOME/.nix-profile/etc/profile.d/hm-session-vars.sh; do
  [[ -r $f ]] && . $f
done
export GOPATH="$HOME/go"
export BUN_INSTALL="$HOME/.bun"
export NARGO_HOME="$HOME/.nargo"
export NVM_DIR="$HOME/.nvm"
path=(
  $HOME/.agents/tools/node_modules/.bin
  $HOME/.opencode/bin
  $HOME/.local/bin
  $HOME/.antigravity/antigravity/bin
  $HOME/.npm-global/bin
  $BUN_INSTALL/bin
  $GOPATH/bin
  $HOME/.avm/bin
  $HOME/.cargo/bin
  $HOME/.local/share/solana/install/active_release/bin
  $HOME/.ascii/bin
  $HOME/.nix-profile/bin
  $path
  /opt/homebrew/bin(N/) # Homebrew after nix, so nix wins on overlaps
  /opt/homebrew/sbin(N/)
  $NARGO_HOME/bin
  $HOME/.risc0/bin
)

# nvm.sh costs ~270 ms: put the default node on PATH, load nvm on first use.
if [[ -d $NVM_DIR/versions/node ]]; then
  nvm_default=
  [[ -r $NVM_DIR/alias/default ]] && nvm_default=$(<$NVM_DIR/alias/default)
  nvm_node=($NVM_DIR/versions/node/v${nvm_default#v}*(N/nOn[1]) $NVM_DIR/versions/node/*(N/nOn[1]))
  (( $#nvm_node )) && path=($nvm_node[1]/bin $path)
  unset nvm_default nvm_node
  nvm() { unfunction nvm; source "$NVM_DIR/nvm.sh"; nvm "$@"; }
fi

if [[ $OSTYPE == darwin* ]]; then
  sdk_cache=${XDG_CACHE_HOME:-$HOME/.cache}/zsh/sdkroot
  [[ -r $sdk_cache && -d $(<$sdk_cache) ]] || { mkdir -p ${sdk_cache:h}; xcrun --sdk macosx --show-sdk-path >|$sdk_cache 2>/dev/null; }
  export SDKROOT=$(<$sdk_cache)
  unset sdk_cache
  export LIBRARY_PATH="$SDKROOT/usr/lib${LIBRARY_PATH:+:$LIBRARY_PATH}"
  export CPATH="$SDKROOT/usr/include${CPATH:+:$CPATH}"
  export LLVM_SYS_211_PREFIX=/opt/homebrew/opt/llvm@21
  alias tailscale=/Applications/Tailscale.app/Contents/MacOS/Tailscale
fi

export ERL_AFLAGS="-kernel shell_history enabled"
export GPG_TTY=$TTY

for f in $HOME/.config/envman/load.sh $HOME/.mesh/env $HOME/.local/bin/env $HOME/.local/bin/watcher-env; do
  [[ -r $f ]] && . $f
done

[[ -e ~/.zsh_history && ! -w ~/.zsh_history ]] && { rm -f ~/.zsh_history; touch ~/.zsh_history; }
HISTFILE=~/.zsh_history
HISTSIZE=2000
SAVEHIST=$HISTSIZE
setopt appendhistory sharehistory hist_ignore_space hist_ignore_all_dups hist_save_no_dups hist_ignore_dups hist_find_no_dups

# Plugin paths come from nix (modules/home/zsh.nix), pinned by flake.lock.
typeset -gA zplugin
[[ -r ~/.local/share/zsh/plugins.zsh ]] && source ~/.local/share/zsh/plugins.zsh
zsource() { [[ -r $zplugin[$1] ]] && source $zplugin[$1] }

# Source a command's generated init script from a cache keyed on the binary's
# install dir (a nix store hash or a Homebrew version), so upgrades refresh it.
cached_eval() {
  local bin=${commands[$2]}
  [[ -n $bin ]] || return
  local f=${XDG_CACHE_HOME:-$HOME/.cache}/zsh/$1-${bin:A:h:h:t}.zsh
  [[ -s $f ]] || { mkdir -p ${f:h}; rm -f ${f:h}/$1-*.zsh(N); "${@:2}" >|$f; } # drop older versions
  source $f
}

zsource p10k
fpath=($zplugin[completions] $fpath)

# Full compinit check at most once a day.
autoload -Uz compinit
() {
  setopt local_options extendedglob
  if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) || ! -e ${ZDOTDIR:-$HOME}/.zcompdump ]]; then
    compinit
  else
    compinit -C
  fi
}
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'
[[ -r $BUN_INSTALL/_bun ]] && source $BUN_INSTALL/_bun

zsource fzf-tab # after compinit, before plugins that wrap widgets
cached_eval fzf fzf --zsh
cached_eval zoxide zoxide init zsh
# Not for agents (Claude Code snapshots this shell): zoxide's cd jumps to a
# frecent match when the path doesn't exist, so `cd build && rm -rf *` could hit another dir.
[[ -z $AI_AGENT$CLAUDECODE$OPENCODE ]] && cached_eval zoxide-cd zoxide init --cmd cd zsh
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
ZSH_AUTOSUGGEST_USE_ASYNC=1
zsource autosuggestions

bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
bindkey '^[w' kill-region
zsource highlighting # last: it wraps every widget defined before it

[[ -r ~/.p10k.zsh ]] && source ~/.p10k.zsh
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
(( ! ${+functions[p10k]} )) || p10k finalize
typeset -g POWERLEVEL9K_INSTANT_PROMPT=off

# omp and pi are pinned in ~/.agents/tools; `omp update` / `pi update` bump the pin.
agent-update() { (cd ~/.agents/tools && bun add --exact "$@" && cp bun.lock node_modules/.bun.lock.installed) }
omp() { if [[ $* == update ]]; then agent-update @oh-my-pi/pi-coding-agent@latest; else command omp "$@"; fi }
pi() { if [[ $* == update ]]; then agent-update @earendil-works/pi-coding-agent@latest; else command pi "$@"; fi }

alias ls='ls --color'
alias clear='clear && clear'

# ASCII BOAT SHELL INTEGRATION START boat
boat() {
  current_file=$(mktemp)
  convo_file=$(mktemp)
  old_current_file=${BOAT_CURRENT_ID_FILE-}
  old_convo_file=${BOAT_CURRENT_CONVO_FILE-}
  export BOAT_CURRENT_ID_FILE="$current_file"
  export BOAT_CURRENT_CONVO_FILE="$convo_file"
  command "$HOME/.ascii/bin/boat" "$@"
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

