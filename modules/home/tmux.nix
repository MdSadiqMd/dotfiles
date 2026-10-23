{ lib, pkgs, ... }:
let
  tmux = "${pkgs.tmux}/bin/tmux";
in
{
  # Plugins from nixpkgs (pinned) instead of tpm's runtime git clones. Output is
  # silenced: nixpkgs' continuum.tmux runs under `set -x`.
  xdg.dataFile."tmux/plugins.conf".text = ''
    run-shell "${pkgs.tmuxPlugins.resurrect.rtp} >/dev/null 2>&1"
    run-shell "${pkgs.tmuxPlugins.continuum.rtp} >/dev/null 2>&1"
  '';

  # Start the server at login so continuum restores the last save.
  launchd.agents.tmux = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        tmux
        "start-server"
      ];
      RunAtLoad = true;
      # The server daemonizes; don't kill it when this job exits.
      AbandonProcessGroup = true;
      EnvironmentVariables.PATH = "${pkgs.tmux}/bin:/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
    };
  };

  systemd.user.services.tmux = lib.mkIf pkgs.stdenv.isLinux {
    Unit.Description = "tmux server";
    Service = {
      Type = "forking";
      ExecStart = "${tmux} start-server";
      ExecStop = "${tmux} kill-server";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
