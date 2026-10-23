{
  inputs,
  lib,
  pkgs,
  vars,
  ...
}:
let
  installerPath = lib.makeBinPath (
    with pkgs;
    [
      bash
      coreutils
      curl
      gnugrep
      gnutar
      gzip
    ]
  );
in
{
  targets.genericLinux.enable = !vars.linuxIsNixOS;
  programs.home-manager.enable = true;

  home.packages =
    let
      p = import ../packages.nix pkgs;
    in
    p.common ++ p.linux ++ [ pkgs.nerd-fonts.jetbrains-mono ];
  fonts.fontconfig.enable = true;

  nix = {
    package = pkgs.nix;
    # Lands in ~/.config/nix/registry.json (git-ignored).
    registry.nixpkgs.flake = inputs.nixpkgs;
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 14d";
    };
  };

  home.activation.startGc = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run systemctl --user start --no-block nix-gc.service 2>/dev/null || true
  '';

  # rtk is not in nixpkgs; its installer uses ~/.local/bin.
  home.activation.installRtk = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -x "$HOME/.local/bin/rtk" ]; then
      PATH=${installerPath}:$PATH run sh -c 'curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh'
    fi
  '';
}
