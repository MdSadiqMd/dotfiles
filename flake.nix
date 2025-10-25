{
  description = "Example nix-darwin system flake with .zshrc in nix folder";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    mac-app-util.url = "github:hraban/mac-app-util";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    home-manager.url = "github:nix-community/home-manager";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, mac-app-util, nix-homebrew, home-manager, rust-overlay }:
  let
    configuration = { pkgs, ... }: {
      system.primaryUser = "sadiq";
      nixpkgs.config.allowUnfree = true;

      users.users.sadiq = {
        name = "sadiq";
        home = "/Users/sadiq";
      };

      # Install specific versions of development tools
      environment.systemPackages = with pkgs; [
        vim
        obsidian
        git
        go_1_24
        rust-bin.stable."1.87.0".default
        nodejs_20
        nodePackages.typescript
      ];

      environment.variables = {
        HOMEBREW_NO_ANALYTICS = "1";
      };

      homebrew = {
        enable = true;
        casks = [
          "hammerspoon"
	  "ghostty"
          "alt-tab"
	  "docker"
        ];
	brews = [
    	  "fzf"
    	  "zoxide"
    	  "gnupg"
	  "pinentry-mac"
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
        ({ pkgs, ... }: {
          nixpkgs.overlays = [ rust-overlay.overlays.default ];
        })
        
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
            users.sadiq = { config, lib, pkgs, ... }: {
		home = {
    homeDirectory = "/Users/sadiq";
    stateVersion = "24.05";
    username = "sadiq";
  };

  # Use absolute path string, NOT a relative path
  xdg.configFile."ghostty/config".source = 
    config.lib.file.mkOutOfStoreSymlink "/Users/sadiq/.config/nix/ghostty-config";

  home.activation = {
    createZshrcSymlink = lib.hm.dag.entryAfter ["writeBoundary"] ''
      if [ ! -L "$HOME/.zshrc" ]; then
        echo "Creating symlink from ~/.zshrc to nix folder..."
        $DRY_RUN_CMD ln -sf "/Users/sadiq/.config/nix/.zshrc" "$HOME/.zshrc"
      fi
    '';

    createGhosttySymlink = lib.hm.dag.entryAfter ["writeBoundary"] ''
      if [ -f "/Applications/Ghostty.app/Contents/MacOS/Ghostty" ] && [ ! -L "/usr/local/bin/ghostty" ]; then
        echo "Creating symlink for Ghostty..."
        $DRY_RUN_CMD sudo ln -sf "/Applications/Ghostty.app/Contents/MacOS/Ghostty" "/usr/local/bin/ghostty"
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

