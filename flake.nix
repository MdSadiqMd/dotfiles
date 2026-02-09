{
  description = "I use Nix btw";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nix-darwin.url = "github:LnL7/nix-darwin/nix-darwin-25.11";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    mac-app-util.url = "github:hraban/mac-app-util";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    home-manager.url = "github:nix-community/home-manager";
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

          # Disable automatic optimization due to macOS hardlinking issues
          nix.optimise.automatic = false;

          # space-aware settings
          nix.settings = {
            # Trigger GC when free space drops below 100MB
            # Stop GC when 1GB is available (prevents excessive GC runs)
            min-free = 100 * 1024 * 1024; # 100 MB
            max-free = 1024 * 1024 * 1024; # 1 GB

            # Keep derivations (.drv files) to enable quick rebuilds
            # This allows rollback without redownloading
            keep-derivations = true;

            # Supress Warnings
            warn-dirty = false;

            # WARNING: Only enable if you have space or develop frequently
            # keep-outputs = false;  # Default - reclaims build-time deps
          };

          # Clean old generations on system activation (rebuild/reboot)
          system.activationScripts.cleanupGenerations.text = ''
            echo "Cleaning up old Nix generations (keeping last 5)..."

            # Delete old system generations (keep last 5)
            ${pkgs.nix}/bin/nix-env --delete-generations +5 --profile /nix/var/nix/profiles/system 2>/dev/null || true

            # Delete old user generations (keep last 5)
            sudo -u sadiq ${pkgs.nix}/bin/nix-env --delete-generations +5 2>/dev/null || true

            # Run garbage collection to free up space
            echo "Running garbage collection..."
            ${pkgs.nix}/bin/nix-collect-garbage -d 2>/dev/null || true

            echo "Cleanup complete!"
          '';

          # Install specific versions of development tools
          environment.systemPackages = with pkgs; [
            anchor
            vim
            obsidian
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
            rustup
            yarn
            pkg-config
            openssl
            clang
            libiconv
            perl
            curl
          ];

          environment.variables = {
            HOMEBREW_NO_ANALYTICS = "1";
            LIBRARY_PATH = "${pkgs.libiconv}/lib";
          };

          homebrew = {
            enable = true;
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
            {
              nixpkgs.overlays = [ rust-overlay.overlays.default ];
            }
          )

          configuration
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
                  };

                  home.packages = with pkgs; [
                    curl
                  ];

                  # Use absolute path string, NOT a relative path
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

                    installGitButler = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                      if [ -x "$HOME/.local/bin/but" ]; then
                        echo "GitButler already installed, skipping..."
                      else
                        echo "Installing GitButler (sandboxed)..."

                        export ZDOTDIR="$(mktemp -d)"
                        export REAL_HOME="$HOME"
                        export HOME="$ZDOTDIR"

                        ${pkgs.curl}/bin/curl -fsSL https://gitbutler.com/install.sh \
                          | env PATH=${
                            lib.makeBinPath [
                              pkgs.curl
                              pkgs.bash
                              pkgs.coreutils
                              pkgs.gnugrep
                              pkgs.gnused
                              pkgs.gawk
                            ]
                          } bash

                        if [ -x "$ZDOTDIR/.local/bin/but" ]; then
                          mkdir -p "$REAL_HOME/.local/bin"
                          mv "$ZDOTDIR/.local/bin/but" "$REAL_HOME/.local/bin/but"
                          chmod +x "$REAL_HOME/.local/bin/but"
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
