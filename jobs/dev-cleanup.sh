#!/usr/bin/env bash
# Removes regenerable dev artifacts so they don't pile up: build output of projects untouched
# for $DAYS days, and package caches that have no eviction of their own once they pass a cap.
# Never touches sources, data, models, VMs, emulators, Docker volumes or agent chats.
# Tools that already clean themselves are left alone: nix (nix-cleanup), Cargo's registry,
# Go's build cache, Gradle, Homebrew, Docker's build cache (daemon.json caps it at 20 GB).
# DRY_RUN=1 lists what would go without deleting.
set -u
PATH="$PATH:/usr/local/bin" # docker
DAYS=30
dry=${DRY_RUN:-}

log() { echo "$(date '+%F %T') $*"; }
gb() { du -sk "$1" 2>/dev/null | awk '{print int($1 / 1048576)}'; }
remove() {
  log "remove $(du -sh "$1" 2>/dev/null | cut -f1) $1${2:+ ($2)}"
  [ -n "$dry" ] || rm -rf "$1"
}
# True when anything under $1 changed in the last $DAYS days, ignoring build output and .git.
recent() {
  [ -n "$(find "$1" -maxdepth "${2:-5}" \( -name node_modules -o -name target -o -name .venv -o -name .git \) -prune \
    -o -type f -mtime -"$DAYS" -print -quit 2>/dev/null)" ]
}
# A monorepo counts as one project, so a quiet package inside an active repo keeps its deps.
project_root() { git -C "$1" rev-parse --show-toplevel 2>/dev/null || echo "$1"; }
has() {
  local dir=$1 f
  shift
  for f; do [ -e "$dir/$f" ] && return 0; done
  return 1
}
# Working directories and command lines of everything running: an idle project that a service
# still runs from keeps its dependencies.
busy=$({
  lsof -a -d cwd -Fn 2>/dev/null | sed -n 's/^n//p'
  ps -axo command=
})
# Substring match: a sibling like proj2 also protects proj, which errs on the side of keeping.
in_use() { grep -qF "$1" <<<"$busy"; }
locks=(package-lock.json pnpm-lock.yaml yarn.lock bun.lock bun.lockb)

# Project build output. Dot-folders are skipped (agent tools live in ~/.agents/tools/node_modules),
# except T3 worktrees.
find "$HOME" "$HOME/.t3/worktrees" -maxdepth 7 \
  \( -path "$HOME/Library" -o \( -path "$HOME/.*" ! -path "$HOME/.t3/worktrees*" \) \) -prune \
  -o -type d \( -name node_modules -o -name .venv -o -name target \) -print -prune 2>/dev/null |
  while read -r dir; do
    parent=${dir%/*}
    root=$(project_root "$parent")
    case ${dir##*/} in
      node_modules) has "$parent" "${locks[@]}" || has "$root" "${locks[@]}" || continue ;;
      .venv) has "$parent" pyproject.toml uv.lock setup.py requirements.txt || continue ;;
      target) [ -f "$parent/Cargo.toml" ] || continue ;;
    esac
    recent "$root" && continue
    in_use "$root" && {
      log "keep $dir: project idle but in use"
      continue
    }
    if [ "${dir##*/}" = target ]; then
      # target/deploy holds Solana program keypairs, which cannot be regenerated.
      for entry in "$dir"/* "$dir"/.[!.]*; do
        [ -e "$entry" ] && [ "${entry##*/}" != deploy ] && remove "$entry" "project idle ${DAYS}d"
      done
    else
      remove "$dir" "project idle ${DAYS}d"
    fi
  done

# Cargo intermediates (config/cargo/config.toml puts them here, one folder per workspace).
# A workspace past 50 GB is rebuilt from scratch rather than left to grow without bound.
cargo_running=$(pgrep -x cargo || pgrep -x rustc)
for dir in "$HOME"/.cargo/build/*/*; do
  [ -d "$dir" ] || continue
  if ! recent "$dir" 4; then
    remove "$dir" "cargo build dir idle ${DAYS}d"
  elif [ -z "$cargo_running" ] && [ "$(gb "$dir")" -ge 50 ]; then
    remove "$dir" "cargo build dir over 50 GB"
  fi
done

# Xcode DerivedData of projects not built for $DAYS days, and simulators whose runtime is gone.
for dir in "$HOME"/Library/Developer/Xcode/DerivedData/*/; do
  [ -d "$dir" ] && ! recent "$dir" 3 && remove "${dir%/}" "not built for ${DAYS}d"
done
command -v xcrun >/dev/null && [ -z "$dry" ] && xcrun simctl delete unavailable 2>/dev/null

# Caches with no eviction of their own: wiped once past a cap, skipped while the tool runs.
# cap <process> <dir> <GB> <command...>
cap() {
  local proc=$1 dir=$2 limit=$3 size
  shift 3
  [ -d "$dir" ] || return
  pgrep -x "$proc" >/dev/null && return # checked first: measuring a large cache takes a minute
  size=$(gb "$dir")
  [ "$size" -ge "$limit" ] || return
  log "clean $dir: ${size} GB over the ${limit} GB cap"
  [ -n "$dry" ] || "$@" >/dev/null 2>&1 || log "  failed: $*"
}
command -v uv >/dev/null && {
  # Fails fast when a uv process holds the cache (uvx servers do while they run).
  [ -n "$dry" ] || UV_LOCK_TIMEOUT=5 uv cache prune >/dev/null 2>&1 || log "uv cache prune skipped: cache in use"
  cap uv "$(uv cache dir 2>/dev/null)" 30 env UV_LOCK_TIMEOUT=5 uv cache clean
}
command -v go >/dev/null && cap go "$(go env GOMODCACHE)" 10 go clean -modcache
command -v npm >/dev/null && cap npm "$HOME/.npm/_cacache" 5 npm cache clean --force
command -v yarn >/dev/null && cap yarn "$(yarn cache dir 2>/dev/null)" 5 yarn cache clean
command -v bun >/dev/null && cap bun "$HOME/.bun/install/cache" 5 bun pm cache rm
command -v pnpm >/dev/null && [ -z "$dry" ] && pnpm store prune >/dev/null 2>&1

# Docker images no container uses, older than $DAYS days (re-pulled or rebuilt on demand).
if timeout 10 docker info >/dev/null 2>&1; then
  if [ -n "$dry" ]; then
    log "would prune unused Docker images older than ${DAYS}d"
  else
    docker image prune -af --filter "until=$((DAYS * 24))h" 2>/dev/null | tail -1
  fi
fi
log "done"
