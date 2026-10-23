{
  config,
  inputs,
  pkgs,
  vars,
  ...
}:
let
  nix = config.nix.package;
  background = {
    ProcessType = "Background";
    LowPriorityIO = true;
    Nice = 10;
  };

  # GC with failure tracking: a failed run falls back to collecting only
  # unreferenced paths, and three failures in a row raise a notification.
  cleanup = pkgs.writeShellScript "nix-cleanup" ''
    state=/var/lib/nix-cleanup
    mkdir -p "$state"
    if ${nix}/bin/nix-collect-garbage --delete-older-than 14d >/dev/null 2>"$state/last-error"; then
      date +%s >"$state/last-success"
      rm -f "$state/failures"
      exit 0
    fi
    failures=$(($(cat "$state/failures" 2>/dev/null || echo 0) + 1))
    echo "$failures" >"$state/failures"
    ${nix}/bin/nix-store --gc >/dev/null 2>>"$state/last-error" || true
    if [ "$failures" -ge 3 ]; then
      launchctl asuser "$(id -u ${vars.user})" sudo -u ${vars.user} /usr/bin/osascript -e \
        "display notification \"Failed $failures times in a row, see $state/last-error\" with title \"Nix cleanup\""
    fi
    exit 1
  '';
in
{
  nix = {
    settings = {
      experimental-features = "nix-command flakes";
      max-jobs = "auto";
      max-substitution-jobs = 32;
      http-connections = 50;
      # The 64 MiB default stalls large downloads.
      download-buffer-size = 256 * 1024 * 1024;
      # Safety net independent of the cleanup job: whenever free space drops below
      # 5 GiB during a build or download, nix collects garbage until 20 GiB is free.
      min-free = 5 * 1024 * 1024 * 1024;
      max-free = 20 * 1024 * 1024 * 1024;
      warn-dirty = false;
    };

    # `nix shell nixpkgs#x` reuses this flake's nixpkgs instead of downloading one.
    registry.nixpkgs.flake = inputs.nixpkgs;
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    channel.enable = false;

    gc.automatic = false; # replaced by nix-cleanup below
    # Not auto-optimise-store: it can corrupt the store on macOS (NixOS/nix#7273).
    optimise.automatic = true;
  };

  # Daily, so a failure is retried the next day; runs missed while asleep happen on wake.
  launchd.daemons.nix-cleanup.serviceConfig = background // {
    ProgramArguments = [ "${cleanup}" ];
    StartCalendarInterval = [
      {
        Hour = 22;
        Minute = 0;
      }
    ];
  };
  launchd.daemons.nix-optimise.serviceConfig = background;

  # Each switch keeps 5 generations, then cleanup and dedupe run in the background.
  system.activationScripts.postActivation.text = ''
    ${nix}/bin/nix-env --profile /nix/var/nix/profiles/system --delete-generations +5 >/dev/null 2>&1 || true
    launchctl kickstart system/org.nixos.nix-cleanup || true
    launchctl kickstart system/org.nixos.nix-optimise || true
  '';
}
