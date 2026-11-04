{ lib, pkgs, ... }:
{
  home.activation = {
    # Unpinned: a pin lands in uv's receipt and would block `cswap upgrade`. --python
    # because uv would otherwise settle on the older system Python, which it rejects.
    installClaudeSwap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -x "$HOME/.local/bin/cswap" ]; then
        run ${pkgs.uv}/bin/uv tool install --python 3.13 claude-swap \
          || echo "warning: could not install claude-swap (offline?); next switch retries"
      fi
    '';

    # Leaves the system resolver to Twingate; modules/darwin/default.nix routes ts.net.
    tailscaleAcceptDnsOff = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ts=/Applications/Tailscale.app/Contents/MacOS/Tailscale
      if [ -x "$ts" ]; then
        run "$ts" set --accept-dns=false \
          || echo "warning: could not set Tailscale accept-dns=false; Twingate names may not resolve"
      fi
    '';

    # The installer edits rc files under $HOME, so it gets a throwaway HOME.
    installSurfpool = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -x "$HOME/.local/bin/surfpool" ]; then
        realHome="$HOME"
        tmpHome="$(mktemp -d)"
        (
          export HOME="$tmpHome" ZDOTDIR="$tmpHome"
          run ${pkgs.curl}/bin/curl -sL https://run.surfpool.run/ \
            | env PATH=${pkgs.curl}/bin:${pkgs.gzip}/bin:${pkgs.gnutar}/bin:${pkgs.coreutils}/bin:${pkgs.bash}/bin bash
        )
        if [ -x "$tmpHome/.local/bin/surfpool" ]; then
          mkdir -p "$realHome/.local/bin"
          mv "$tmpHome/.local/bin/surfpool" "$realHome/.local/bin/surfpool"
        fi
      fi
    '';

    trimGenerations = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      for p in "$genProfilePath" "$HOME/.local/state/nix/profiles/profile"; do
        [ -e "$p" ] && run ${pkgs.nix}/bin/nix-env --profile "$p" --delete-generations +5 2>/dev/null || true
      done
    '';
  };
}
