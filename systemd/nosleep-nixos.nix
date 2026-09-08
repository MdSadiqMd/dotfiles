# NixOS module - Linux equivalent of:
#   sudo pmset -a disablesleep 1
#   sudo pmset -a sleep 0
#   sudo pmset -a displaysleep 0
#   sudo pmset -a disksleep 0
#
# Usage on NixOS: add to your configuration.nix imports:
#   imports = [ ./systemd/nosleep-nixos.nix ];
# Or copy the relevant stanzas into your flake's NixOS configuration.
#
# Revert: set `nosleep.enable = false;` and `nixos-rebuild switch`, or see UNDO section below.

{ pkgs, lib, ... }:
let
  cfg = {
    enable = true;
  };
in
{
  # 1. Inhibitor service - equivalent to systemd-inhibit + sleep infinity
  #    This blocks: idle, sleep, handle-lid-switch (including docked)
  systemd.services.nosleep = lib.mkIf cfg.enable {
    description = "Prevent all sleep including lid-closed (pmset disablesleep 1 equivalent)";
    wantedBy = [ "multi-user.target" ];
    before = [
      "sleep.target"
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
      "suspend-then-hibernate.target"
    ];
    serviceConfig = {
      ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=sleep:idle:handle-lid-switch:handle-lid-switch-docked --who=nosleep --why=Prevent sleep lid closed and idle --mode=block ${pkgs.coreutils}/bin/sleep infinity";
      Restart = "always";
      RestartSec = 5;
    };
  };

  # 2. logind - ignore lid switch and idle (critical for lid-closed)
  services.logind.settings.Login = lib.mkIf cfg.enable {
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    IdleAction = "ignore";
    HandlePowerKey = "ignore";
  };

  # 3. sleep.conf - disable suspend/hibernate at systemd level
  systemd.sleep.extraConfig = lib.mkIf cfg.enable ''
    AllowSuspend=no
    AllowHibernation=no
    AllowSuspendThenHibernate=no
    AllowHybridSleep=no
  '';

  # 4. Hard mask the targets (strongest, like disablesleep 1)
  systemd.targets.sleep.enable = !cfg.enable;
  systemd.targets.suspend.enable = !cfg.enable;
  systemd.targets.hibernate.enable = !cfg.enable;
  systemd.targets.hybrid-sleep.enable = !cfg.enable;

  # --- UNDO / REVERT (NixOS) ---
  # Option A (declarative): set cfg.enable = false above and run:
  #   sudo nixos-rebuild switch
  #
  # Option B (imperative, immediate):
  #   sudo systemctl disable --now nosleep.service
  #   sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
  #   sudo systemctl daemon-reload
  #   # then revert logind.conf:
  #   sudo sed -i '/HandleLidSwitch/d; /IdleAction/d' /etc/systemd/logind.conf
  #   sudo systemctl restart systemd-logind
  #   # and revert sleep.conf:
  #   sudo sed -i '/AllowSuspend/d; /AllowHibernation/d' /etc/systemd/sleep.conf
}
