# NixOS: never sleep, even with the lid closed (pmset disablesleep 1 equivalent).
# Import from a NixOS configuration; set cfg.enable = false and rebuild to undo.

{ pkgs, lib, ... }:
let
  cfg = {
    enable = true;
  };
in
{
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

  services.logind.settings.Login = lib.mkIf cfg.enable {
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    IdleAction = "ignore";
    HandlePowerKey = "ignore";
  };

  systemd.sleep.extraConfig = lib.mkIf cfg.enable ''
    AllowSuspend=no
    AllowHibernation=no
    AllowSuspendThenHibernate=no
    AllowHybridSleep=no
  '';

  systemd.targets.sleep.enable = !cfg.enable;
  systemd.targets.suspend.enable = !cfg.enable;
  systemd.targets.hibernate.enable = !cfg.enable;
  systemd.targets.hybrid-sleep.enable = !cfg.enable;
}
