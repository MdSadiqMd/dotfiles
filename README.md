# Nix

macOS (nix-darwin + home-manager) and Linux (home-manager) config. Every config file lives here; the usual paths (`~/.zshrc`, `~/.claude`, `~/.config/opencode`, `~/.pi`, ...) are symlinks into this repo, created by `modules/home/links.nix` on every switch.

## Setup

Edit `vars.nix` (user, host, systems, repo path), then:

```sh
git clone https://github.com/MdSadiqMd/Nix.git ~/.config/nix && ~/.config/nix/bootstrap.sh
```

Secrets are sops-encrypted, but the age key is not in this repo: restore the passphrase-protected backup (`age-key.age`, kept in your password manager) to `~/.config/sops/age/keys.txt` before the first switch. Work commits get their address from `~/.gitconfig-work.local`, which is also outside the repo.

Forking this? `secrets/secrets.yaml` is encrypted to my key, so replace it with your own (`.sops.yaml` names the key). Secrets missing from it are skipped. `git-private` holds your git email and any `includeIf` blocks, for example:

```gitconfig
[user]
	email = you@example.com
[includeIf "gitdir:~/work/"]
	path = ~/.gitconfig-work
```

Ubuntu: first `sudo apt install -y git curl xz-utils`. Bootstrap also sets up GPU drivers for nix GUI apps and makes nix's zsh your login shell (log out and back in once). Set `linuxSystem` in `vars.nix` to `aarch64-linux` on ARM.

Not automated, do by hand on a new machine: import the GPG key (`gpg --import`, commits are signed), add SSH keys, install Docker and the Claude Code / OpenCode CLIs with their own installers, and reinstall claudemon if you want its status line.

Day to day: `just fmt` (format everything), `just update` (apply config changes), `just rebuild` (upgrade everything to newer versions). New files must be `git add`ed first: flakes ignore untracked files.

## Layout

| Path                               | What                                                                                       |
| ---------------------------------- | ------------------------------------------------------------------------------------------ |
| `vars.nix`                         | user, host, systems, repo path                                                             |
| `flake.nix`                        | inputs, `darwinConfigurations`, `homeConfigurations`                                       |
| `modules/packages.nix`             | packages for both OSes, plus Linux stand-ins for Homebrew                                  |
| `modules/darwin/`                  | macOS system: nix settings, Homebrew, launchd agents                                       |
| `modules/home/`                    | user: symlinks, AGENTS.md sync, activation, darwin/linux parts                             |
| `modules/nixos/`                   | nosleep service for a NixOS machine (not imported)                                         |
| `config/`                          | dotfiles: zsh, git, tmux, ghostty, nvim, zed, herdr, hammerspoon                           |
| `jobs/`                            | job scripts; schedules live in `modules/home/jobs.nix` (launchd / systemd)                 |
| `agents/`                          | `~/.agents`: `CLAUDE.md` (rules), generated `AGENTS.md`, `RTK.md`, `skills/`               |
| `agents/{claude,opencode,pi,omp}/` | per-agent config                                                                           |
| `agents/tools/`                    | omp and pi, pinned by `bun.lock` (`omp update` / `pi update` bump it)                      |
| `secrets/`                         | sops-encrypted secrets (`just secrets` to edit); the age key backup stays outside the repo |
| `nix.conf`                         | user nix config (nix reads `~/.config/nix/nix.conf` itself)                                |
