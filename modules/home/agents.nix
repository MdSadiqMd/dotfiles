{
  lib,
  pkgs,
  vars,
  ...
}:
let
  dir = "${vars.repoDir}/agents";
  watched = [
    "${dir}/CLAUDE.md"
    "${dir}/RTK.md"
  ];

  # AGENTS.md = CLAUDE.md with `@file` imports inlined (other agents don't follow them).
  syncAgentsMd = pkgs.writeShellScript "sync-agents-md" ''
    cd ${lib.escapeShellArg dir} || exit 0
    tmp=$(mktemp AGENTS.md.XXXXXX)
    ${pkgs.gawk}/bin/awk '/^@[^ ]+$/ { f = substr($0, 2); while ((getline l < f) > 0) print l; close(f); next } { print }' CLAUDE.md > "$tmp"
    if cmp -s "$tmp" AGENTS.md; then rm "$tmp"; else chmod 644 "$tmp" && mv "$tmp" AGENTS.md; fi
  '';
in
{
  home.activation.syncAgentsMd = lib.hm.dag.entryAfter [ "writeBoundary" ] "run ${syncAgentsMd}";

  # omp and pi are pinned by agents/tools/bun.lock; install only when it changed.
  home.activation.installAgentTools = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    (
      cd ${lib.escapeShellArg "${dir}/tools"}
      if ! cmp -s bun.lock node_modules/.bun.lock.installed; then
        run ${pkgs.bun}/bin/bun install --frozen-lockfile && run cp bun.lock node_modules/.bun.lock.installed
      fi
    )
  '';

  # Event-driven (kqueue/inotify), nothing polls.
  launchd.agents.sync-agents-md = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [ "${syncAgentsMd}" ];
      WatchPaths = watched;
    };
  };

  systemd.user = lib.mkIf pkgs.stdenv.isLinux {
    paths.sync-agents-md = {
      Unit.Description = "Regenerate AGENTS.md when CLAUDE.md changes";
      Path.PathChanged = watched;
      Install.WantedBy = [ "default.target" ];
    };
    services.sync-agents-md = {
      Unit.Description = "Regenerate AGENTS.md from CLAUDE.md";
      Service = {
        Type = "oneshot";
        ExecStart = "${syncAgentsMd}";
      };
    };
  };
}
