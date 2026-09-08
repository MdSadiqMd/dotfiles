{
  description = "I use Nix btw";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nix-darwin.url = "github:LnL7/nix-darwin/nix-darwin-25.11";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    mac-app-util.url = "github:hraban/mac-app-util";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs =
    inputs@{
      self,
      nix-darwin,
      nixpkgs,
      mac-app-util,
      nix-homebrew,
      home-manager,
      rust-overlay,
    }:
    let
      configuration =
        { pkgs, lib, ... }:
        {
          system.primaryUser = "sadiq";
          nixpkgs.config.allowUnfree = true;

          users.users.sadiq = {
            name = "sadiq";
            home = "/Users/sadiq";
          };

          nix.gc = {
            automatic = true;
            interval = {
              Weekday = 5;
              Hour = 22;
              Minute = 0;
            };
            options = "--delete-older-than 14d";
          };

          nix.optimise.automatic = false;

          nix.settings = {
            # Trigger GC when free space drops below 100MB
            # Stop GC when 1GB is available (prevents excessive GC runs)
            min-free = 100 * 1024 * 1024; # 100 MB
            max-free = 1024 * 1024 * 1024; # 1 GB

            # Keep derivations (.drv files) to enable quick rebuilds
            # This allows rollback without redownloading
            keep-derivations = true;
            warn-dirty = false;
          };

          system.activationScripts.cleanupGenerations.text = ''
            echo "Cleaning up old Nix generations (keeping last 5)..."
            ${pkgs.nix}/bin/nix-env --delete-generations +5 --profile /nix/var/nix/profiles/system 2>/dev/null || true
            sudo -u sadiq ${pkgs.nix}/bin/nix-env --delete-generations +5 2>/dev/null || true
            echo "Running garbage collection..."
            ${pkgs.nix}/bin/nix-collect-garbage -d 2>/dev/null || true
            echo "Cleanup complete!"
          '';

          environment.systemPackages = with pkgs; [
            anchor
            vim
            lean4
            obsidian
            tmux
            git
            go_1_24
            neovim
            nodejs_20
            typescript
            postgresql_17
            protobuf
            nixfmt
            nh
            python311
            (python311.withPackages (
              ps: with ps; [
                pip
                virtualenv
              ]
            ))
            (rust-bin.stable."1.87.0".default.override {
              extensions = [
                "clippy"
                "rust-src"
              ];
              targets = [ "wasm32-unknown-unknown" ];
            })
            wasm-pack
            wasm-bindgen-cli
            binaryen
            rustup
            yarn
            pkg-config
            openssl
            clang
            libiconv
            perl
            curl
            erlang
            elixir
            beamPackages.rebar3
            beamPackages.hex
            nodePackages.npm
            nodePackages.yarn
            nodePackages.node2nix
            watchexec
            ncurses
            libyaml
          ];

          environment.variables = {
            HOMEBREW_NO_ANALYTICS = "1";
            LIBRARY_PATH = "${pkgs.libiconv}/lib";
            ERL_AFLAGS = "-kernel shell_history enabled";
          };

          homebrew = {
            enable = true;
            taps = [
              "rtk-ai/tap"
            ];
            casks = [
              "anydesk"
              "hammerspoon"
              "ghostty"
              "alt-tab"
              "docker-desktop"
              "rustdesk"
              "wireshark-app"
            ];
            brews = [
              "b2-tools"
              "fzf"
              "zoxide"
              "gnupg"
              "ffmpeg"
              "pinentry-mac"
              "tree"
              "htop"
              "watch"
              "kubectl"
              "kind"
              "kubeshark"
              "solana"
              "rtk"
              "just"
            ];
            onActivation.cleanup = "zap";
            onActivation.autoUpdate = true;
            onActivation.upgrade = true;
          };

          nix.settings.experimental-features = "nix-command flakes";
          system.configurationRevision = self.rev or self.dirtyRev or null;
          system.stateVersion = 6;
        };

    in
    {
      darwinConfigurations."sadiq" = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";

        modules = [
          (
            { pkgs, ... }:
            let
              disableNodeTests = final: prev: {
                nodejs = prev.nodejs.overrideAttrs (old: {
                  doCheck = false;
                });
                nodejs_22 =
                  if prev ? nodejs_22 then
                    prev.nodejs_22.overrideAttrs (old: {
                      doCheck = false;
                    })
                  else
                    null;
                nodejs_20 =
                  if prev ? nodejs_20 then
                    prev.nodejs_20.overrideAttrs (old: {
                      doCheck = false;
                    })
                  else
                    null;
              };
            in
            {
              nixpkgs.overlays = [
                rust-overlay.overlays.default
                disableNodeTests
              ];
            }
          )

          configuration
          ./nosleep.nix
          mac-app-util.darwinModules.default
          nix-homebrew.darwinModules.nix-homebrew

          {
            nix-homebrew = {
              enable = true;
              enableRosetta = true;
              user = "sadiq";
            };
          }

          home-manager.darwinModules.home-manager

          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;

              users.sadiq =
                {
                  config,
                  lib,
                  pkgs,
                  ...
                }:
                {
                  home = {
                    homeDirectory = "/Users/sadiq";
                    stateVersion = "24.05";
                    username = "sadiq";
                    enableNixpkgsReleaseCheck = false;
                  };

                  home.packages = with pkgs; [
                    curl
                  ];

                  xdg.configFile."ghostty/config".source =
                    config.lib.file.mkOutOfStoreSymlink "/Users/sadiq/.config/nix/ghostty-config";

                  home.activation = {
                    createZshrcSymlink = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                      if [ ! -L "$HOME/.zshrc" ]; then
                        echo "Creating symlink from ~/.zshrc to nix folder..."
                        $DRY_RUN_CMD ln -sf "/Users/sadiq/.config/nix/.zshrc" "$HOME/.zshrc"
                      fi
                    '';

                    createGhosttySymlink = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                      if [ -f "/Applications/Ghostty.app/Contents/MacOS/Ghostty" ] && [ ! -L "/usr/local/bin/ghostty" ]; then
                        echo "Creating symlink for Ghostty..."
                        $DRY_RUN_CMD sudo ln -sf "/Applications/Ghostty.app/Contents/MacOS/Ghostty" "/usr/local/bin/ghostty"
                      fi
                    '';

                    installSurfpool = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                      if [ -x "$HOME/.local/bin/surfpool" ]; then
                        echo "surfpool already installed at $HOME/.local/bin/surfpool, skipping..."
                      else
                        echo "Installing surfpool via official installer..."

                        # Prevent installer from modifying real shell config
                        export ZDOTDIR="$(mktemp -d)"
                        export HOME="$ZDOTDIR"

                        $DRY_RUN_CMD \
                          ${pkgs.curl}/bin/curl -sL https://run.surfpool.run/ \
                          | env \
                              PATH=${pkgs.curl}/bin:${pkgs.gzip}/bin:${pkgs.gnutar}/bin:${pkgs.coreutils}/bin:${pkgs.bash}/bin \
                              bash

                        # Move binary to the real location ourselves (idempotent)
                        if [ -x "$ZDOTDIR/.local/bin/surfpool" ]; then
                          mkdir -p "$REAL_HOME/.local/bin"
                          mv "$ZDOTDIR/.local/bin/surfpool" "$REAL_HOME/.local/bin/surfpool"
                          chmod +x "$REAL_HOME/.local/bin/surfpool"
                        fi
                      fi
                    '';

                    cleanupHomeGenerations = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                      echo "Cleaning up old home-manager generations (keeping last 5)..."
                      $DRY_RUN_CMD ${pkgs.nix}/bin/nix-env --delete-generations +5 --profile "$HOME/.local/state/home-manager/profiles/home-manager" 2>/dev/null || true
                    '';
                  };

                  programs.zsh.enable = false;
                };
            };
          }
        ];
      };

      darwinPackages = self.darwinConfigurations."sadiq".pkgs;
    };
}
