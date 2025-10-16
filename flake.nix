{
  description = "Example nix-darwin system flake with .zshrc in nix folder";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    mac-app-util.url = "github:hraban/mac-app-util";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    home-manager.url = "github:nix-community/home-manager";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, mac-app-util, nix-homebrew, home-manager }:
  let
    configuration = { pkgs, ... }: {
      system.primaryUser = "sadiq";
      nixpkgs.config.allowUnfree = true;

      users.users.sadiq = {
        name = "sadiq";
        home = "/Users/sadiq";
      };

      environment.systemPackages = [
        pkgs.vim
        pkgs.obsidian
        pkgs.git
      ];

      environment.variables = {
        HOMEBREW_NO_ANALYTICS = "1";
      };

      homebrew = {
        enable = true;
        casks = [
          "hammerspoon"
          "ghostty"
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
              
              # Simple approach: just create a symlink from home to nix folder
              home.activation = {
                createZshrcSymlink = lib.hm.dag.entryAfter ["writeBoundary"] ''
                  if [ ! -L "$HOME/.zshrc" ]; then
                    echo "Creating symlink from ~/.zshrc to nix folder..."
                    $DRY_RUN_CMD ln -sf "/Users/sadiq/.config/nix/.zshrc" "$HOME/.zshrc"
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
