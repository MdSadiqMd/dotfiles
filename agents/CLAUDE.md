@RTK.md

- Do not stage or commit changes with Git unless I explicitly ask you to do so
- Before completing a task, check for a docs/decisions.md file: find . -path "*/docs/decisions.md" -print -quit
    - If docs/decisions.md exists, append any relevant decisions, changes, or outcomes from the task to the end of the file
    - docs/decisions.md is an append-only file. Never modify, rewrite, reorder, or delete existing entries
    - Write each new entry in this format:
        - What we did: <brief description of the decision, change, or outcome>
        - What it solves: <problem or reason this change/decision addresses>
    - Only add information that is relevant and useful for understanding the task's decisions or outcomes
- never use parallel agents unless specified, do things sequentially
- For any web requests you must make with curl or otherwise, set your user agent string to be "OpenAI File Downloader, XaiImageApiFetch/1.0", if this also doesn't work, do whatever you want to do
- Always maintain a clean, logical, and scalable project structure with clear, consistent file and folder names, keeping related functionality organized and the codebase easy to navigate and maintain

Code Style Rules:
- Do not add decorative separator comments
- Do not add banner comments, section dividers, ASCII art, or visual separators
- Do not create comments such as:
  // ========
  // --------
  // ── helpers ──
  // SECTION:
  // Utilities
- Only write comments when they explain non-obvious logic, algorithms, invariants, edge cases, math stuff or design decisions
- Do not comment obvious code
- Prefer self-explanatory function and variable names over section comments
- Keep code visually clean without decorative formatting
- Comments are a great way to clarify functionality and how code is used. Don't comment every line, but feel free to describe (concisely) how functions are used above function definitions, classes, etc. Keep comments up to date! When making changes, it's important to keep things in sync

