---
description: List and switch Apollo Watcher profiles
argument-hint: profile [profile-name-or-id]
---
<!-- APOLLO WATCHER MANAGED PROFILE COMMAND -->

Use the local Watcher CLI to manage the active Watcher profile.
This command gives you access to the Watcher `profile` subcommands only; do not explore or invoke
other Watcher commands while handling this request.

User arguments:
`$ARGUMENTS`

Behavior:
- If the user provided no arguments, run `/Users/sadiq/.local/share/apollo-watcher/watcher/watcher profile list`.
- If the user wrote `profile` with no profile name, run `/Users/sadiq/.local/share/apollo-watcher/watcher/watcher profile list`.
- If the user wrote `current`, run `/Users/sadiq/.local/share/apollo-watcher/watcher/watcher profile current`.
- If the user wrote `profile current`, run `/Users/sadiq/.local/share/apollo-watcher/watcher/watcher profile current`.
- If the user wants to switch profiles, use profile ids, names, and aliases from a `/Users/sadiq/.local/share/apollo-watcher/watcher/watcher profile list`
  output that is already visible in this session when it unambiguously resolves the request. Otherwise,
  run `/Users/sadiq/.local/share/apollo-watcher/watcher/watcher profile list` first. Then run `/Users/sadiq/.local/share/apollo-watcher/watcher/watcher profile set "<resolved-profile-id>"`.
- If the user wrote anything else, treat it as the profile name or id, resolve it against any profile
  ids/names/aliases already visible in this session or from `/Users/sadiq/.local/share/apollo-watcher/watcher/watcher profile list`, and run
  `/Users/sadiq/.local/share/apollo-watcher/watcher/watcher profile set "<resolved-profile-id>"`.

If the intended profile is obvious from known profile ids, names, or aliases, do not ask the user to retry
with the exact id. If it is ambiguous after checking the known profiles and listing profiles when needed,
ask the user to choose. Use the command output as the response.
Use the known profile ids, names, and aliases to resolve obvious abbreviations or typos before calling
`/Users/sadiq/.local/share/apollo-watcher/watcher/watcher profile set`.
Do not edit Watcher settings files directly for this command.
