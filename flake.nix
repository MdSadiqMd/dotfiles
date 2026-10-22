{
  description = "I use Nix btw";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin/nix-darwin-25.11";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    mac-app-util.url = "github:hraban/mac-app-util";
    # macOS 27: mac-app-util's bundled SBCL crashes ("failed to allocate
    # 1048576 bytes at 0x300100000") unless it is built with SBCL >= 2.6.6.
    # See hraban/mac-app-util#20. Keep this on unstable; the rest of the
    # system stays on nixos-25.11.
    mac-app-util.inputs.nixpkgs.follows = "nixpkgs-unstable";
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
      nixpkgs-unstable,
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
            gh
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

          # Start OpenWhispr at login so headless dictation is available after
          # a reboot. The pgrep guard keeps `open -a` from re-activating an
          # already running instance during agent reloads.
          launchd.user.agents.openwhispr = {
            script = ''
              if ! /usr/bin/pgrep -f "[O]penWhispr.app/Contents/MacOS/OpenWhispr" >/dev/null 2>&1; then
                /usr/bin/open -a /Applications/OpenWhispr.app
              fi
            '';
            serviceConfig.RunAtLoad = true;
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
              "openwhispr"
              "rustdesk"
              "wireshark-app"
            ];
            brews = [
              "b2-tools"
              "blueutil"
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
            onActivation.cleanup = "none"; # ponytail: zap disabled — nix-darwin 25.11 passes `brew bundle --cleanup` which brew 7.x removed; re-enable when nix-darwin supports brew 7 (new syntax: `brew bundle install --force-cleanup --zap`)
            onActivation.autoUpdate = true;
            # Auto-upgrade runs `brew bundle --upgrade`, and cask upgrades that
            # need sudo fail under nix-darwin's root activation (no TTY).
            # Upgrade manually with `brew upgrade` instead.
            onActivation.upgrade = false;
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
                    gh
                  ];

                  xdg.configFile."ghostty/config".source =
                    config.lib.file.mkOutOfStoreSymlink "/Users/sadiq/.config/nix/ghostty-config";

                  xdg.configFile."tmux/tmux.conf".source =
                    config.lib.file.mkOutOfStoreSymlink "/Users/sadiq/.config/nix/tmux.conf";

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

                    # Hide the idle floating bar and show it only while dictating.
                    # Merges these keys into the app's .env instead of replacing
                    # the file, so models, hotkeys and other settings survive.
                    openwhisprSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                      ENV_DIR="$HOME/Library/Application Support/open-whispr"
                      ENV_FILE="$ENV_DIR/.env"
                      $DRY_RUN_CMD mkdir -p "$ENV_DIR"
                      tmp="$(mktemp)"
                      if [ -f "$ENV_FILE" ]; then
                        # Remove the old voice-agent hotkey too. Right Command must
                        # never open OpenWhispr; only Right Option dictates.
                        ${pkgs.gawk}/bin/awk -v keys="START_MINIMIZED FLOATING_ICON_AUTO_HIDE HIDE_DICTATION_UI PANEL_START_POSITION DICTATION_LANGUAGE VOICE_AGENT_KEY CHAT_AGENT_KEY" '
                          BEGIN { n = split(keys, k, " "); for (i = 1; i <= n; i++) skip[k[i]] = 1 }
                          { key = $0; sub(/=.*/, "", key); if (!(key in skip)) print }
                        ' "$ENV_FILE" > "$tmp"
                      else
                        printf '# OpenWhispr Environment Variables\n' > "$tmp"
                      fi
                      cat >> "$tmp" <<'OPENWHISPR_ENV'
                      START_MINIMIZED=true
                      FLOATING_ICON_AUTO_HIDE=true
                      PANEL_START_POSITION=bottom-right
                      DICTATION_LANGUAGE=auto
                      OPENWHISPR_ENV
                      $DRY_RUN_CMD mv "$tmp" "$ENV_FILE"
                    '';

                    # OpenWhispr has no free-form Whisper prompt setting. The
                    # custom dictionary is the only text it forwards as the
                    # local Whisper initial prompt. Language=auto alone is not
                    # enough: an English instruction/word list makes Whisper
                    # translate short Telugu ("ela unnav raa" -> "How are you?").
                    # Phrase-level Romanized Telugu examples keep the output in
                    # Latin script; the trailing English phrases keep ordinary
                    # English dictation from being pulled into the Telugu prompt.
                    openwhisprTinglishPrompt = lib.hm.dag.entryAfter [ "openwhisprSettings" ] ''
                      DB="$HOME/Library/Application Support/open-whispr/transcriptions.db"
                      PROMPT="ela unnav raa. nenu baga unnanu. meeru ela unnaru. repu office ki veltunnanu. meeting padhi gantalaki undhi. idi enti raa. naku telusu. manam ekkadiki veltunnam. em chestunnav. please update cheyandi. real or not real. yo bro whats up."
                      if [ -f "$DB" ]; then
                        $DRY_RUN_CMD ${pkgs.sqlite}/bin/sqlite3 -cmd ".timeout 5000" "$DB" \
                          "DELETE FROM custom_dictionary WHERE word LIKE 'The following is Telugu speech%' OR word LIKE 'ela unnav raa%'; DELETE FROM custom_dictionary WHERE word = 'OpenWhispr'; INSERT INTO custom_dictionary (word, source) VALUES ('$PROMPT', 'manual'); INSERT INTO custom_dictionary (word, source) VALUES ('OpenWhispr', 'manual');" \
                          || echo "warning: could not seed OpenWhispr Tinglish prompt (database busy?)"
                        # Keep the spelling the user asked for, and leave the
                        # Whisper prompt ending on an English phrase so short
                        # English dictation is not pulled into the Telugu examples.
                        # The English entry is a no-op anchor: its trigger is
                        # appended to the STT prompt, but it must not rewrite a
                        # longer sentence such as "please send the report to John".
                        $DRY_RUN_CMD ${pkgs.sqlite}/bin/sqlite3 -cmd ".timeout 5000" "$DB" \
                          "DELETE FROM snippets WHERE trigger IN ('yela unnav raa', 'please send the report'); INSERT INTO snippets (trigger, replacement) VALUES ('yela unnav raa', 'ela unnav raa'); INSERT INTO snippets (trigger, replacement) VALUES ('please send the report', 'please send the report');" \
                          || echo "warning: could not seed OpenWhispr Tinglish snippets (database busy?)"
                      fi
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
