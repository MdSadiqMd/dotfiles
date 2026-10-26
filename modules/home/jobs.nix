{
  lib,
  pkgs,
  vars,
  ...
}:
let
  # Scheduled and background jobs, defined once for launchd (macOS) and systemd (Linux).
  #   script:    path in this repo, or command: a shell command line
  #   at:        daily { hour, minute }; missed runs happen on wake/boot
  #   keepAlive: a long-running service, restarted if it exits
  #   darwinOnly
  # Output goes to ~/.local/state/jobs/<name>.log.
  jobs = {
    claude-warmup = {
      script = "jobs/claude-warmup.sh";
      at = {
        hour = 9;
        minute = 0;
      };
    };
    helmet-comfort-report = {
      command = "cd ~/${vars.workDir}/vision && monitoring/venv/bin/python monitoring/helmet_comfort_report.py";
      at = {
        hour = 8;
        minute = 0;
      };
      darwinOnly = true;
    };
    t3-network-guard = {
      script = "jobs/t3-network-guard.sh";
      keepAlive = true;
      darwinOnly = true;
    };
  };

  logDir = "${vars.home}/.local/state/jobs";
  path = lib.concatStringsSep ":" [
    "${vars.home}/.local/bin"
    "/etc/profiles/per-user/${vars.user}/bin"
    "/run/current-system/sw/bin"
    "${vars.home}/.nix-profile/bin"
    "/opt/homebrew/bin"
    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin"
  ];
  run = job: if job ? script then "${vars.repoDir}/${job.script}" else job.command;
  active = lib.filterAttrs (_: job: pkgs.stdenv.isDarwin || !(job.darwinOnly or false)) jobs;
  scheduled = lib.filterAttrs (_: job: job ? at) active;
in
{
  launchd.agents = lib.mkIf pkgs.stdenv.isDarwin (
    lib.mapAttrs (name: job: {
      enable = true;
      config = {
        ProgramArguments = [
          "${pkgs.bash}/bin/bash"
          "-c"
          (run job)
        ];
        EnvironmentVariables.PATH = path;
        StandardOutPath = "${logDir}/${name}.log";
        StandardErrorPath = "${logDir}/${name}.log";
        LowPriorityIO = true;
      }
      // lib.optionalAttrs (job ? at) {
        StartCalendarInterval = [
          {
            Hour = job.at.hour;
            Minute = job.at.minute;
          }
        ];
        ProcessType = "Background";
      }
      // lib.optionalAttrs (job.keepAlive or false) {
        RunAtLoad = true;
        KeepAlive = true;
      };
    }) active
  );

  systemd.user.services = lib.mkIf pkgs.stdenv.isLinux (
    lib.mapAttrs (
      name: job:
      {
        Unit.Description = name;
        Service = {
          ExecStart = "${pkgs.bash}/bin/bash -c ${lib.escapeShellArg (run job)}";
          Environment = "PATH=${path}";
          StandardOutput = "append:${logDir}/${name}.log";
          StandardError = "append:${logDir}/${name}.log";
          Nice = 10;
          IOSchedulingClass = "idle";
        }
        // (if job.keepAlive or false then { Restart = "always"; } else { Type = "oneshot"; });
      }
      // lib.optionalAttrs (job.keepAlive or false) { Install.WantedBy = [ "default.target" ]; }
    ) active
  );

  systemd.user.timers = lib.mkIf pkgs.stdenv.isLinux (
    lib.mapAttrs (name: job: {
      Unit.Description = name;
      Timer = {
        OnCalendar = "*-*-* ${toString job.at.hour}:${lib.fixedWidthNumber 2 job.at.minute}:00";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    }) scheduled
  );

  home.activation.jobLogDir = lib.hm.dag.entryAfter [ "writeBoundary" ] "run mkdir -p ${logDir}";
}
