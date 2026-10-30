#!/usr/bin/env bash
# New machine: installs Nix, clones this repo, runs the first switch. Safe to re-run.
set -euo pipefail

REPO="https://github.com/MdSadiqMd/Nix.git"
DIR="$HOME/.config/nix"
NIX=(nix --extra-experimental-features "nix-command flakes")

if [ "$(uname)" = Darwin ] && ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install
  echo "Re-run this script once the Command Line Tools finish installing."
  exit 1
fi

if [ "$(uname)" = Linux ]; then
  for c in git curl xz; do
    command -v "$c" >/dev/null 2>&1 || {
      echo "Missing $c. On Ubuntu: sudo apt install -y git curl xz-utils"
      exit 1
    }
  done
fi

if ! command -v nix >/dev/null 2>&1; then
  curl -fsSL https://nixos.org/nix/install | sh -s -- --daemon --yes
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

[ -d "$DIR/.git" ] || git clone "$REPO" "$DIR"

# Secrets key: the passphrase-protected backup stays out of this repo (in the
# password manager). Restore it to KEY before the first switch.
KEY="$HOME/.config/sops/age/keys.txt"
BACKUP="$HOME/.config/sops/age/backup.age"
if [ ! -f "$KEY" ] && [ -f "$BACKUP" ]; then
  echo "Secrets: enter the key backup passphrase."
  mkdir -p "$(dirname "$KEY")"
  (umask 077 && "${NIX[@]}" run nixpkgs#age -- -d -o "$KEY" "$BACKUP")
elif [ ! -f "$KEY" ]; then
  echo "Secrets: no key at $KEY. Restore age-key.age from your password manager there, then continue."
fi

if [ "$(uname)" = Darwin ]; then
  # The first nix-darwin activation refuses to overwrite these.
  for f in /etc/bashrc /etc/zshrc; do
    if [ -f "$f" ] && [ ! -L "$f" ]; then sudo mv "$f" "$f.before-nix-darwin"; fi
  done
  host=$("${NIX[@]}" eval --raw --file "$DIR/vars.nix" host)
  if command -v darwin-rebuild >/dev/null 2>&1; then
    sudo darwin-rebuild switch --flake "$DIR#$host"
  else
    sudo "${NIX[@]}" run nix-darwin/nix-darwin-25.11#darwin-rebuild -- switch --flake "$DIR#$host"
  fi
else
  "${NIX[@]}" run home-manager/release-25.11 -- switch -b before-nix --flake "$DIR"
  hm="$HOME/.nix-profile/bin"
  # Lets nix-built GUI apps (Ghostty, Obsidian) find the GPU drivers; re-run when
  # a switch warns that GPU drivers need an update.
  if [ ! -e /run/opengl-driver ] && [ -x "$hm/non-nixos-gpu-setup" ]; then
    sudo "$(readlink -f "$hm/non-nixos-gpu-setup")"
  fi
  zsh="$hm/zsh" # stable across upgrades, unlike a store path
  grep -qx "$zsh" /etc/shells || echo "$zsh" | sudo tee -a /etc/shells >/dev/null
  [ "$(getent passwd "$USER" | cut -d: -f7)" = "$zsh" ] || sudo chsh -s "$zsh" "$USER"
fi
