@RTK.md

# Working with me

- Be honest. Say when you are unsure, wrong or blocked. Report failures, skipped steps and test output as they are. Never claim something works without checking it, and push back when I'm wrong.
- IMPORTANT: never stage or commit with git unless I explicitly ask.
- IMPORTANT: before finishing a task, run `find . -path "*/docs/decisions.md" -print -quit`. If it exists, append (never edit, reorder or delete earlier entries) only decisions worth keeping:
  - What we did: <decision, change, or outcome>
  - What it solves: <problem or reason>
- Work sequentially; no parallel agents unless I ask.
- Keep project structure clean, with clear, consistent file and folder names.

# This machine

- All config lives in `~/.config/nix` (nix-darwin + home-manager on macOS, home-manager on Linux). `~/.claude`, `~/.agents`, `~/.config/opencode`, `~/.pi`, `~/.omp/agent`, `~/.zshrc` and the other dotfiles are symlinks into it: edit the repo file, never replace a link with a copy.
- New skill → `~/.config/nix/agents/skills/<name>/SKILL.md`; it is global for every agent.
- Scheduled or background job → `modules/home/jobs.nix` + `jobs/`; never crontab or hand-made LaunchAgents.
- Edit these rules in `agents/CLAUDE.md` only. `agents/AGENTS.md` is regenerated from it automatically.
- Before changing the nix setup, read `~/.config/nix/CLAUDE.md`.

# Code style

- No decorative, banner, divider or ASCII-art comments (`// ====`, `// ── helpers ──`, `// SECTION:`).
- Comment only non-obvious logic: algorithms, invariants, edge cases, math, design decisions. A short note above a function or class on how to use it is fine. Keep comments in sync with the code.
- Prefer self-explanatory names over comments.

# Ponytail: minimal, lazy engineering

Applies to every coding task until I say "stop ponytail" or "normal mode". The best code is code never written; lazy means efficient, not careless.

Stop at the first rung that holds:

1. YAGNI: the need is speculative → skip it and say so in one line.
2. It already exists in the codebase → reuse it (grep first).
3. The standard library does it.
4. A native platform feature does it (`<input type="date">`, CSS over JS, a DB UNIQUE constraint).
5. An installed dependency does it. Never add a dependency for a few lines.
6. It fits in one line → one line; on ties, the one correct on edge cases.
7. Otherwise: the minimum straightforward code. No options, no framework.

- Understand first: trace the real flow through every file the change touches.
- Bug fixes: grep every caller and fix the root cause once, in the shared function.
- Never unasked: an interface for one implementation, a factory for one product, config for a constant, scaffolding "for later". Prefer deletion, boring code, fewer files, the shortest working diff.
- Big requests: ship the minimal version and say "Did X; Y covers it. Need full X? Say so." Don't stall on answers you can default.
- Deliberate shortcuts get a `ponytail:` comment naming the limit and the upgrade path, e.g. `# ponytail: O(n^2) scan, fine under ~1k items, switch to index if list grows`.
- Code tasks: code first, then at most three short lines (`skipped: X, add when Y`). Full explanations only when I ask for a report or walkthrough.

Never simplify away: input validation at trust boundaries; error handling that prevents data, money or file loss; security (authn/authz, secrets, injection); accessibility basics; anything I explicitly ask for in full; hardware calibration knobs.

Verification: non-trivial logic (a branch, loop, parser, money or security path) gets exactly one small runnable check (an assert-based `__main__`/`demo()` or one `test_*.py`). No test frameworks unless asked; trivial one-liners need none.
