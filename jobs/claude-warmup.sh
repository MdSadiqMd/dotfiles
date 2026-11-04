#!/usr/bin/env bash
# Anchors Claude's 5-hour usage window with one tiny Haiku request. Skips MCP servers,
# skills and user settings (hooks, plugins): the request is all that matters.
# Disabled in modules/home/jobs.nix: Claude Code no longer has a 5-hour usage limit.
echo "=== $(date '+%F %T %Z') ==="
# Keep the Mac awake for the call.
command -v caffeinate >/dev/null && caffeinate -u -t 120 &
# Not $HOME: there ~/.claude/settings.json would load as project settings.
cd /tmp || exit 1
claude -p hi --model haiku --no-session-persistence \
  --strict-mcp-config --disable-slash-commands --setting-sources project
echo "exit=$?"
