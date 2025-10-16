{
  description = "Example nix-darwin system flake with symlinked .zshrc";

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

      homebrew = {
        enable = true;
        casks = [
          "hammerspoon"
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
              
              # Use activation script to create symlink only if .zshrc doesn't exist
              home.activation = {
                linkZshrc = let 
                  zshrcPath = "/Users/sadiq/.zshrc";
                in lib.hm.dag.entryAfter ["writeBoundary"] ''
                  if [ ! -e "${zshrcPath}" ]; then
                    echo "Creating initial .zshrc file..."
                    touch "${zshrcPath}"
                  fi
                  if [ ! -L "${zshrcPath}" ]; then
                    echo "Creating symlink for .zshrc..."
                    $DRY_RUN_CMD ln -sf "${zshrcPath}" "$HOME/.zshrc"
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
