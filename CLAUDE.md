# Nix config repo

macOS: nix-darwin + home-manager (`darwinConfigurations.<host>`). Linux: standalone home-manager (`homeConfigurations.<user>`). Every config file lives here; `modules/home/links.nix` symlinks it into place.

## Layout

- `vars.nix`: the only place for user, host, systems and the repo path. Never hard-code `/Users/...` or `/home/...` in nix; use `vars.home` / `vars.repoDir`. Dotfiles use `$HOME` or `~`.
- `modules/packages.nix`: `common` (both OSes) and `linux` (what Homebrew provides on macOS).
- `modules/darwin/`: system settings, nix daemon/GC, Homebrew (brew is a normal checkout installed on first activation; nix-darwin manages the Brewfile), launchd agents.
- `modules/home/`: `links.nix` (every symlink), `agents.nix` (AGENTS.md sync, agent CLIs), `tmux.nix` (plugins, server at login), `jobs.nix` (scheduled/background jobs), `zsh.nix` (zsh plugin paths), `activation.nix`, `openwhispr.nix` (macOS), `linux.nix`.
- `config/<tool>/`: dotfiles. `agents/`: shared rules, skills and per-agent config (`claude/`, `opencode/`, `pi/`, `omp/`). `agents/tools/`: omp and pi pinned by `bun.lock`.
- Secrets: `secrets/secrets.yaml` is sops-encrypted (age key in `~/.config/sops/age/keys.txt`, passphrase-encrypted backup outside the repo at `~/.config/sops/age/backup.age`) and committed; sops-nix (`modules/home/secrets.nix`) decrypts each entry to `~/.config/sops-nix/secrets/<name>`. Every credential lives there (gh/git token, API keys, SSH/GPG keys, wallet keypairs); tools that rewrite their credential files (gcloud, kubeconfig, OAuth logins) are the exception. Add one: `just secret-add <name> <file>` (or pipe stdin), then add `<name>` to `secrets` in `modules/home/secrets.nix` (with `.path` to place it where the tool looks); entries missing from the yaml are skipped. Never write plaintext secrets anywhere in the repo.
- Private values: this repo is meant to be public, so employer, client and project names, private endpoints and email addresses go in sops too, never in the tree. sops key names are plain text, so keep them generic (`ssh-extra-1`, `llm-gateway-url`). Existing ones: `git-private` (git email and the work `includeIf`, linked to `~/.gitconfig.private`), `llm-gateway-url`, `daily-report` (the job's script), `ssh-aliases` (real names of `~/.ssh/extra-N`). These are read at activation or run time; nix eval never sees them.
- Git-ignored, never commit: anything else in `secrets/`, `agents/skills/synced/` and `.trash/` (private claude.ai skills; `agents/skills/.gitignore` also hides them from pi), `agents/tools/node_modules/`, `config/zsh/sessions/`.

## Rules

- Flakes only see git-tracked files. New files must be `git add`ed before a build sees them; ask before staging. To test without staging: `rsync -a --exclude node_modules ./ /tmp/nixtest/ && cd /tmp/nixtest && git add -A`, build there, then run `./result/activate` from `...home-manager.users.<user>.home.activationPackage`.
- New dotfile → `config/<tool>/` plus one `link` line in `modules/home/links.nix`. New package → `modules/packages.nix` (nixpkgs), or `modules/darwin/homebrew.nix` only for casks and tools missing from nixpkgs.
- New skill → `agents/skills/<name>/` (plain files, no nested `.git`).
- Rules: edit `agents/CLAUDE.md`. Never edit `agents/AGENTS.md`; launchd/systemd regenerate it, inlining `@file` imports.
- Prefer out-of-store links (`link` helper) over `home.file.text`: tools write back into their own config.
- Home-manager skips a target whose content already matches; delete the plain copy, then activate.
- Scheduled or background jobs: add an entry to `jobs` in `modules/home/jobs.nix` (script in `jobs/`); it becomes a launchd agent on macOS and a systemd service/timer on Linux. Logs: `~/.local/state/jobs/<name>.log`. Never use crontab or hand-made LaunchAgents.
- nvim: `config/nvim/init.lua` only wires modules: `lua/config/` (options, keymaps, autocmds, lazy), `lua/ide/` (terminal panel, tree, layout, workspace, clicks), `lua/plugins/` (lazy specs). Lazy-load new plugins (event/cmd/keys/ft); `lazy-lock.json` is tracked. LSP servers and formatters come from nix (`modules/packages.nix`), not mason: add the package there and the server to `servers` in `lua/plugins/lsp.lua`.
- zsh plugins come from nixpkgs via `modules/home/zsh.nix` (no plugin manager); `.zshrc` sets the load order.
- Agent CLI updates: `omp update` / `pi update` (zsh wrappers) or `agent-update <pkg>@<ver>` rewrite `agents/tools/bun.lock`; activation installs only when the lock changed. Never update them in place.
- tmux plugins come from `pkgs.tmuxPlugins` via `~/.local/share/tmux/plugins.conf`; don't reintroduce tpm. Hook scripts live in `config/tmux/scripts/`; resurrect saves in `~/.local/share/tmux/resurrect` (`@resurrect-dir`).
- Keep rebuilds cheap: no overlays that change hashes of cached packages, no work in activation scripts unless guarded, no blocking GC: each switch trims to 5 generations and kicks GC/optimise as low-priority background jobs.
- Run `just fmt` after editing (treefmt: nix, shell, lua, json, markdown, yaml, toml; see `treefmt.toml`).

## Apply

`just` lists the commands: `fmt`, `update` (apply the config at pinned versions), `rebuild` (bump flake.lock, apply, `brew upgrade`).

- macOS: `sudo darwin-rebuild switch --flake ~/.config/nix#<host>` (host from `vars.nix`; it is not the machine hostname)
- Linux: `home-manager switch --flake ~/.config/nix`
- New machine: edit `vars.nix`, then run `./bootstrap.sh`.
- Check Linux from macOS: `nix eval .#homeConfigurations.<user>.activationPackage.drvPath`
