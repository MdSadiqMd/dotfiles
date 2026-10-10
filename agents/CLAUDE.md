be honest

@RTK.md

# Global Rules

- Do not stage or commit changes with Git unless I explicitly ask you to do so.
- Before completing a task, check for a docs/decisions.md file: find . -path "*/docs/decisions.md" -print -quit
  - If docs/decisions.md exists, append any relevant decisions, changes, or outcomes from the task to the end of the file.
  - docs/decisions.md is an append-only file. Never modify, rewrite, reorder, or delete existing entries.
  - Write each new entry in this format:
    - What we did: <brief description of the decision, change, or outcome>
    - What it solves: <problem or reason this change/decision addresses>
  - Only add information that is relevant and useful for understanding the task's decisions or outcomes.
- Never use parallel agents unless specified, do things sequentially.
- For any web requests you must make with curl or otherwise, set your user agent string to be "OpenAI File Downloader, XaiImageApiFetch/1.0", if this also doesn't work, do whatever you want to do.
- Always maintain a clean, logical, and scalable project structure with clear, consistent file and folder names, keeping related functionality organized and the codebase easy to navigate and maintain.

# Code Style Rules

- Do not add decorative separator comments.
- Do not add banner comments, section dividers, ASCII art, or visual separators.
- Do not create comments such as:
  // ========
  // --------
  // ── helpers ──
  // SECTION:
  // Utilities
- Only write comments when they explain non-obvious logic, algorithms, invariants, edge cases, math stuff or design decisions.
- Do not comment obvious code.
- Prefer self-explanatory function and variable names over section comments.
- Keep code visually clean without decorative formatting.
- Comments are a great way to clarify functionality and how code is used. Don't comment every line, but feel free to describe (concisely) how functions are used above function definitions, classes, etc. Keep comments up to date! When making changes, it's important to keep things in sync.

# Ponytail: Minimal, Lazy Engineering

Core idea: the best code is the code never written. Every line you add is a line that can break, needs testing, and someone must understand at 3am during an outage. So always choose the smallest solution that actually works. Lazy here means efficient, not careless.

This mode is active on every coding task (writing, adding, refactoring, fixing, reviewing, designing code, choosing libraries) unless I say "stop ponytail" or "normal mode".

## The Ladder: stop at the first rung that holds

Work through these in order. The first one that solves the problem is the right answer. If two rungs both work, take the higher one (smaller number = lazier = better).

### 1. Does this need to exist at all? (YAGNI)

- What it means: YAGNI = "You Aren't Gonna Need It". If the need is speculative ("we might need this later", "just in case"), skip it and say so in one line.
- Why: Speculative features add bugs and maintenance cost for zero current value. "Later" can build for itself when it actually arrives.
- Example: Asked to "add a cache for API responses" with no evidence of slowness -> no cache yet. Say: "Skipped cache, no measured slowness. Add when profiler shows it."

### 2. Already in this codebase? Reuse it.

- What it means: Before writing anything new, look for an existing helper, utility function, type, or pattern a few files away that already does it.
- Why: Re-implementing what already exists is the most common source of bloat. Two copies means two places to fix bugs.
- How: Search the repo first (grep/glob for the function or behavior) before creating a new file or function.

### 3. Does the standard library do it? (stdlib)

- What it means: "stdlib" = the standard library, the built-in modules that ship with your language (Python's `functools`, `pathlib`, `datetime`; JS's built-in `fetch`, `URL`, `Array` methods; etc.). No install needed.
- Why: Stdlib is already tested, already installed, and every other developer knows it. Custom code for the same job is a second, worse copy to maintain.
- Example: Custom cache class -> `@functools.lru_cache(maxsize=1000)` on the fetch function. One line, done.

### 4. Does a native platform feature cover it?

- What it means: The platform (browser, CSS, HTML, database) often already solves the problem without code. Use that before writing logic.
- Why: Native features are faster, more reliable, and need zero maintenance from you.
- Examples:
  - Date picker library -> `<input type="date">` built into the browser.
  - JS show/hide or styling logic -> plain CSS (`:hover`, media queries, grid).
  - "Check this value is unique" in app code -> a database UNIQUE constraint.

### 5. Does an already-installed dependency solve it?

- What it means: If a package already listed in the project does the job, use it. Never add a brand-new dependency for what a few lines can do.
- Why: Every new dependency is a liability: install time, security updates, breaking changes, version conflicts. A few lines you own are cheaper than a library you now depend on.

### 6. Can it be one line? Write one line.

- What it means: If the whole job collapses to a single expression, decorator, or call, do that. Do not wrap it in a class or multi-file structure.
- Tie-breaker: If two stdlib/one-line options are the same size, pick the one that is correct on edge cases (empty input, null, timezone, leap year, etc.). Lazy means less code, not a flimsier algorithm.

### 7. Only then: minimum code that works.

- What it means: If no rung above holds, write the smallest straightforward code that fixes the real case. No extra options, no "framework".

## Understand first, then be lazy

- The ladder shortens the solution, never the reading. Always read the task and trace the real flow end to end (every file the change touches) before picking a rung.
- The smallest change in the wrong place is not lazy, it is a second bug. Comprehension first, minimal diff second.

## Bug fixes: fix the root cause, not the symptom

- What it means: A bug report names one path that broke, but the real defect usually lives in a shared function all callers route through.
- How: Before editing, grep every caller of the function you are about to touch. Fix it once in the shared function (one guard there) instead of patching each caller separately or only the path the ticket named.
- Why: One guard in the shared function is a smaller diff and fixes sibling callers that are still broken but not yet reported.

## What never to build unasked

- No unrequested abstractions. An "abstraction" is a generic layer (interface, factory, plugin system, config file) meant to handle future cases. Do not add one when there is only one real case today.
  - One implementation -> no interface. Write the concrete class/function directly.
  - One product -> no factory. Call the constructor directly.
  - One value that never changes -> no config option. Hardcode it.
- No boilerplate or scaffolding "for later". Later can scaffold for itself.
- Deletion over addition. If you can remove code and the behavior stays, remove it.
- Boring over clever. Clever one-liners that take 10 minutes to decode will hurt someone at 3am. Prefer the obvious loop, the plain `if`, the standard pattern.
- Fewest files possible. Shortest working diff wins (once you understand the problem).

## Complex requests: ship the lazy version, ask in the same reply

- If asked for something big, implement the minimal version that covers the real need, then add one line: "Did X; Y covers it. Need full X? Say so."
- Never stall waiting for an answer you can default. Default to the simple path and let me upgrade on request.

## Mark deliberate shortcuts with a `ponytail:` comment

- What it means: When you intentionally pick a simple approach that has a known limit (it will not scale forever), leave a one-line comment naming the limit (the "ceiling") and the upgrade path.
- Why: This makes the tradeoff visible so the next person knows exactly when to replace it.
- Examples:
  - `# ponytail: global lock, switch to per-account locks if throughput matters`
  - `# ponytail: O(n^2) scan, fine under ~1k items, switch to index if list grows`
  - `O(n^2)` means the work grows with the square of the items (100 items -> 10,000 steps). Fine for small lists, bad for large ones.

## Output style for code tasks

- Code first. Then at most three short lines: what was skipped, when to add it.
- Pattern: `[code] -> skipped: [X], add when [Y].`
- If the explanation is longer than the code, delete the explanation. Exception: if I explicitly asked for a report, walkthrough, or per-phase notes, give the full explanation.

## When NOT to be lazy (never simplify these away)

1. Input validation at trust boundaries. A "trust boundary" is anywhere outside data enters your code (user input, API request, file upload, URL param). Always validate there; bad input causes crashes and security holes.
2. Error handling that prevents data loss. If a failure could lose user data, money, or files, handle it fully (retries, transactions, backups). Do not swallow errors.
3. Security measures. Authentication, authorization, secrets handling, injection protection (SQL, XSS, command injection). Never cut these for brevity.
4. Accessibility basics. Labels on inputs, keyboard navigation, contrast, alt text. These are required for real users, not optional polish.
5. Anything explicitly requested. If I insist on the full version, build it without re-arguing.
6. Hardware calibration. Real hardware drifts (a real clock runs fast/slow, a sensor reads off, a PCA9685 servo driver runs a few percent fast). Keep the tuning knob/config value even if the model is otherwise minimal, because the physical world needs adjusting in a way pure code cannot predict.

## Verification: leave one runnable check for non-trivial logic

- "Non-trivial" = any branch (`if`), loop, parser, or money/security path. That logic needs exactly one small check that fails if the logic breaks.
- Smallest form that runs: an `assert`-based `demo()` / `__main__` self-check block, or one small `test_*.py` file. No test frameworks, fixtures, or per-function suites unless asked.
- Trivial one-liners need no test. YAGNI applies to tests too.
- Example: a discount function with an `if` gets 3-4 asserts (normal case, boundary, empty/zero case). A renamed variable or one-line stdlib call gets no test.
