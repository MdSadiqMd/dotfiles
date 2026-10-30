{
  lib,
  pkgs,
  vars,
  ...
}:
let
  git = "${pkgs.git}/bin/git";
in
{
  # Homebrew itself is a normal self-updating checkout (nix-managed brew prints
  # "managed by Nix" warnings and repeats one-time notices on every run); nix-darwin
  # only manages the Brewfile below. Installed on first activation, which also
  # replaces an old nix-homebrew setup. Same steps as Homebrew's official installer.
  system.activationScripts.preActivation.text = ''
    if [ ! -d /opt/homebrew/.git ]; then
      echo "installing Homebrew into /opt/homebrew..." >&2
      rm -rf /opt/homebrew/Library/Homebrew /opt/homebrew/Library/.homebrew-is-managed-by-nix \
        /opt/homebrew/bin/brew /opt/homebrew/.managed_by_nix_darwin
      mkdir -p /opt/homebrew
      if (
        cd /opt/homebrew &&
          ${git} init -q &&
          ${git} config remote.origin.url https://github.com/Homebrew/brew &&
          ${git} config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*" &&
          ${git} config --bool core.autocrlf false &&
          ${git} fetch -q --force origin &&
          ${git} fetch -q --force --tags origin &&
          ${git} remote set-head origin --auto >/dev/null &&
          ${git} checkout -q --force -B stable "$(${git} tag --list --sort=-version:refname | head -n1)"
      ); then
        chown -R ${vars.user}:admin /opt/homebrew
      else
        echo "warning: Homebrew install failed; brew steps will be skipped" >&2
      fi
    fi
  '';

  # Brew tools (gpg, rtk, fzf...) on every shell's PATH, after nix packages so nix
  # wins on overlaps (brew's python3 must not shadow nix python).
  environment.profiles = lib.mkAfter [ "/opt/homebrew" ];

  homebrew = {
    enable = true;
    taps = [ "rtk-ai/tap" ];
    casks = [
      "alt-tab"
      "anydesk"
      "docker-desktop"
      "hammerspoon"
      "openwhispr"
      "rustdesk"
      "session-manager-plugin"
      "wireshark-app"
    ];
    brews = [
      "b2-tools"
      "blueutil"
      "fastfetch"
      "ffmpeg"
      "ffuf"
      "fzf"
      "gnupg"
      "htop"
      "just"
      "kind"
      "kubectl"
      "kubeshark"
      "pinentry-mac"
      "rtk"
      "solana"
      "tree"
      "watch"
      "zoxide"
    ];
    # ponytail: off until nix-darwin stops passing `--cleanup`, removed in brew 7.
    onActivation.cleanup = "none";
    # `just rebuild` updates and upgrades Homebrew (with a TTY for sudo casks).
    onActivation.autoUpdate = false;
    onActivation.upgrade = false;
  };
}
