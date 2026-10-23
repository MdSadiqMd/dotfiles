{ lib, pkgs, ... }:
{
  home.activation = {
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
