{ vars, ... }:
{
  imports = [
    ./links.nix
    ./agents.nix
    ./activation.nix
    ./tmux.nix
    ./jobs.nix
    ./zsh.nix
    ./secrets.nix
  ]
  ++ (if vars.isDarwin then [ ./openwhispr.nix ] else [ ./linux.nix ]);

  home = {
    username = vars.user;
    homeDirectory = vars.home;
    stateVersion = "24.05";
    enableNixpkgsReleaseCheck = false;
  };

  # .zshrc is a plain linked file.
  programs.zsh.enable = false;

  # Don't rebuild the options manpage on every change.
  manual.manpages.enable = false;
  news.display = "silent";
}
