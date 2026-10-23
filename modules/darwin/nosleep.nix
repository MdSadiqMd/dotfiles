{ pkgs, lib, ... }:
let
  persist = false;

  nosleep-enable = pkgs.writeShellScriptBin "nosleep-enable" ''
    set -e
    echo "→ Applying pmset no-sleep..."
    sudo /usr/bin/pmset -a disablesleep 1
    sudo /usr/bin/pmset -a sleep 0
    sudo /usr/bin/pmset -a displaysleep 0
    sudo /usr/bin/pmset -a disksleep 0
    echo "✓ Applied."
    echo ""
    pmset -g | grep -E "disablesleep|Sleep|displaysleep|disksleep" || pmset -g
  '';

  nosleep-disable = pkgs.writeShellScriptBin "nosleep-disable" ''
    set -e
    echo "→ Reverting pmset to sane macOS defaults..."
    sudo /usr/bin/pmset -a disablesleep 0
    sudo /usr/bin/pmset -a sleep 10
    sudo /usr/bin/pmset -a displaysleep 10
    sudo /usr/bin/pmset -a disksleep 10
    echo "✓ Reverted (disablesleep 0, sleep 10, displaysleep 10, disksleep 10)."
    echo "  Edit this script if you want different defaults (e.g. sleep 1)."
    echo ""
    pmset -g | grep -E "disablesleep|Sleep|displaysleep|disksleep" || pmset -g
  '';

  nosleep-status = pkgs.writeShellScriptBin "nosleep-status" ''
    echo "== pmset -g =="
    pmset -g
    echo ""
    echo "== pmset -g assertions =="
    pmset -g assertions 2>&1 | head -n 40
  '';
in
{
  environment.systemPackages = [
    nosleep-enable
    nosleep-disable
    nosleep-status
  ];

  # true: re-apply on every boot (undo: false, switch, nosleep-disable).
  launchd.daemons.nosleep = lib.mkIf persist {
    script = ''
      /usr/bin/pmset -a disablesleep 1
      /usr/bin/pmset -a sleep 0
      /usr/bin/pmset -a displaysleep 0
      /usr/bin/pmset -a disksleep 0
    '';
    serviceConfig = {
      Label = "org.nixos.nosleep";
      RunAtLoad = true;
      KeepAlive = false;
    };
  };
}
