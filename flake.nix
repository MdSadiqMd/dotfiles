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
          ];

          environment.variables = {
            HOMEBREW_NO_ANALYTICS = "1";
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
              "fzf"
              "zoxide"
              "gnupg"
              "ffmpeg"
              "pinentry-mac"
              "tree"
              "htop"
              "watch"
              "protobuf"
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
          # Add rust-overlay
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

                    # Clean home-manager generations
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
