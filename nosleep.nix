{ pkgs, lib, ... }:
let
  nosleep-enable = pkgs.writeShellScriptBin "nosleep-enable" ''
    set -e
    echo "→ Applying pmset no-sleep (equivalent to your bash block)..."
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

  # Optional persistent LaunchDaemon: re-applies `disablesleep 1` on every boot.
  # This is the macOS equivalent of a systemd service with WantedBy=multi-user.target.
  #
  # Disabled by default (commented). To make no-sleep persistent across reboots
  # without manually running `nosleep-enable`, uncomment the block below and
  # `darwin-rebuild switch`.
  #
  # To undo: re-comment the block and run `nosleep-disable`, then `darwin-rebuild switch`.

  # launchd.daemons.nosleep = {
  #   script = ''
  #     /usr/bin/pmset -a disablesleep 1
  #     /usr/bin/pmset -a sleep 0
  #     /usr/bin/pmset -a displaysleep 0
  #     /usr/bin/pmset -a disksleep 0
  #   '';
  #   serviceConfig = {
  #     Label = "org.nixos.nosleep";
  #     RunAtLoad = true;
  #     KeepAlive = false;
  #   };
  # };
}
