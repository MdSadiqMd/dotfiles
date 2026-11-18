#!/usr/bin/env bash
# Runs dev-cleanup.sh against a throwaway HOME and checks what it keeps and removes.
# Tool commands are stubbed so the run never touches real caches, Docker or simulators.
set -eu
script="$(cd "$(dirname "$0")" && pwd)/dev-cleanup.sh"
home=$(mktemp -d)
stubs=$(mktemp -d)
trap 'kill "$busy_pid" 2>/dev/null; rm -rf "$home" "$stubs"' EXIT
for tool in docker uv go npm yarn bun pnpm xcrun; do printf '#!/bin/sh\nexit 1\n' >"$stubs/$tool"; done
chmod +x "$stubs"/*

mk() { mkdir -p "$home/$1" && touch "$home/$1/x"; }
mk stale/node_modules && touch "$home/stale/package-lock.json"
mk active/node_modules && touch "$home/active/package-lock.json"
mk nolock/node_modules
mk busy/node_modules && touch "$home/busy/package-lock.json"
mk rust/target/debug && mk rust/target/deploy && touch "$home/rust/Cargo.toml"
mk .agents/tools/node_modules && touch "$home/.agents/tools/bun.lock"
mk .t3/worktrees/wt/node_modules && touch "$home/.t3/worktrees/wt/pnpm-lock.yaml"
mk .cargo/build/aa/oldhash/debug && mk .cargo/build/bb/newhash/debug
find "$home" -exec touch -t 202001010000 {} +
touch "$home/active/src.js" "$home/.cargo/build/bb/newhash/debug/x"
(cd "$home/busy" && exec sleep 60) &
busy_pid=$!
sleep 1

HOME=$home PATH="$stubs:$PATH" bash "$script" >/dev/null

fail=0
gone() { [ ! -e "$home/$1" ] || {
  echo "FAIL: $1 should be removed"
  fail=1
}; }
kept() { [ -e "$home/$1" ] || {
  echo "FAIL: $1 should be kept"
  fail=1
}; }
gone stale/node_modules
gone rust/target/debug
gone .t3/worktrees/wt/node_modules
gone .cargo/build/aa/oldhash
kept active/node_modules
kept nolock/node_modules
kept busy/node_modules
kept rust/target/deploy
kept .agents/tools/node_modules
kept .cargo/build/bb/newhash
[ "$fail" = 0 ] && echo "dev-cleanup: all checks passed"
exit "$fail"
