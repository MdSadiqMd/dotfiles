---
name: agent-history
description: Find and read past agent sessions on this machine (opencode, T3 Code threads, Claude Code transcripts). Use when the user gives a session or thread id, says "read this opencode/T3/claude thread", "recover context from", "continue where we left off", or refers to earlier work by another agent.
---

# Agent history

Past sessions live in three places; `sessions.py` (next to this file) reads them all, read-only:

- opencode: `~/.local/share/opencode/opencode.db` (ids start with `ses_`)
- T3 Code: `~/.t3/userdata/statev2.sqlite` (thread UUIDs; also T3's opencode threads)
- Claude Code: `~/.claude/projects/<cwd-slug>/<session-uuid>.jsonl`

```sh
S=~/.claude/skills/agent-history/sessions.py
python3 -I $S search "motherduck sync"     # newest first: date, source, id, title, directory
python3 -I $S show <id> | tail -n 200       # user + assistant text
python3 -I $S show <id> --tools             # plus tool calls and results
```

- Inside T3 Code, `t3_thread_read` also reads T3 threads.
- Transcripts are long: read the end first (`tail`), then search inside with `grep -n`.
- Summarize what was decided and what is left; don't paste the transcript back.
