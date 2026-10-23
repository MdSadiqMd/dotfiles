{
  self,
  pkgs,
  vars,
  ...
}:
{
  imports = [
    ./nix.nix
    ./homebrew.nix
    ./openwhispr.nix
    ./nosleep.nix
  ];

  nixpkgs.hostPlatform = vars.system;
  nixpkgs.config.allowUnfree = true;

  system.primaryUser = vars.user;
  users.users.${vars.user}.home = vars.home;

  environment.systemPackages = (import ../packages.nix pkgs).common;
  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];

  environment.variables = {
    HOMEBREW_NO_ANALYTICS = "1";
    HOMEBREW_NO_ENV_HINTS = "1";
    HOMEBREW_NO_ASK = "1"; # no [y/n] before upgrades
    HOMEBREW_NO_AUTO_UPDATE = "1"; # `just rebuild` runs `brew update` once
    LIBRARY_PATH = "${pkgs.libiconv}/lib";
  };

  # Don't rebuild the nix-darwin manual on every change.
  documentation.doc.enable = false;
  documentation.info.enable = false;

  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = 6;
}
