#!/usr/bin/env bash
# While a T3 Code / Claude agent session runs: hold a sleep assertion (lid closed on AC
# keeps working) and probe the internet every T3_GUARD_INTERVAL s. After
# T3_GUARD_MAX_FAILURES consecutive failures (all probes down), kill the sessions so
# nothing bills while offline. Idle (no session): no probes, no assertion.
# Env: T3_GUARD_INTERVAL, T3_GUARD_MAX_FAILURES, T3_GUARD_PROBES, T3_GUARD_LOG,
# T3_GUARD_NO_KEEP_AWAKE=1. Extra args are extra pgrep -f session patterns.
set -u
PROBE_INTERVAL="${T3_GUARD_INTERVAL:-60}"
MAX_FAILURES="${T3_GUARD_MAX_FAILURES:-10}"
LOG="${T3_GUARD_LOG:-$HOME/.local/state/t3-network-guard.log}"
KEEP_AWAKE="${T3_GUARD_NO_KEEP_AWAKE:-0}"

# Agent SDK hosts (T3 Code) run `claude ... --input-format stream-json`.
patterns=('claude .*--input-format stream-json' '\.t3/bin/t3 ' 'harness\.loop' 't3 runtime')
for extra in "$@"; do
  if [ "${extra#--}" = "$extra" ]; then
    patterns+=("$extra")
  fi
done

read -ra probe_urls <<<"${T3_GUARD_PROBES:-https://api.anthropic.com/v1/models https://claude.ai https://www.google.com/generate_204}"

mkdir -p "$(dirname "$LOG")"

log() { echo "[$(date '+%F %T')] $*" >>"$LOG"; }
log "guard started (interval=${PROBE_INTERVAL}s max_fail=${MAX_FAILURES} patterns=${patterns[*]})"

fails=0

probe_ok() {
  for url in "${probe_urls[@]}"; do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "$url" 2>/dev/null)
    case "$code" in
      200 | 204 | 301 | 302 | 401 | 403) return 0 ;;
    esac
  done
  return 1
}

any_session_running() {
  for p in "${patterns[@]}"; do
    if pgrep -f "$p" >/dev/null 2>&1; then return 0; fi
  done
  return 1
}

stop_sessions() {
  log "STOPPING agent sessions after $fails consecutive network failures"
  for p in "${patterns[@]}"; do
    log "  pkill -f '$p'"
    pkill -f "$p" 2>/dev/null
  done
  sleep 3
  for p in "${patterns[@]}"; do
    pgrep -f "$p" >/dev/null 2>&1 && pkill -9 -f "$p" 2>/dev/null
  done
  log "all matching processes signalled; guard will keep probing (it can be restarted manually)"
}

caffeinate_pid=""
keep_awake() {
  if [ "$KEEP_AWAKE" = 0 ] && ! { [ -n "$caffeinate_pid" ] && kill -0 "$caffeinate_pid" 2>/dev/null; }; then
    caffeinate -s &
    caffeinate_pid=$!
  fi
}
allow_sleep() {
  [ -n "$caffeinate_pid" ] && kill "$caffeinate_pid" 2>/dev/null
  caffeinate_pid=""
}
trap 'allow_sleep; exit 0' TERM INT

while true; do
  if ! any_session_running; then
    allow_sleep
    fails=0
    sleep "$PROBE_INTERVAL" &
    wait $!
    continue
  fi
  keep_awake
  if probe_ok; then
    if ((fails > 0)); then
      log "network recovered after $fails failures, counter reset"
    fi
    fails=0
  else
    fails=$((fails + 1))
    log "probe FAILED ($fails/$MAX_FAILURES)"
    if ((fails >= MAX_FAILURES)); then
      stop_sessions
      allow_sleep
      fails=0
      while ! probe_ok; do sleep 30; done
      log "network back up, sessions may be restarted"
    fi
  fi
  sleep "$PROBE_INTERVAL" &
  wait $!
done
