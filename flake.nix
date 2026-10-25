{
  description = "I use Nix btw";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nix-darwin.url = "github:LnL7/nix-darwin/nix-darwin-25.11";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      ...
    }:
    let
      vars = import ./vars.nix;
      varsFor =
        system:
        let
          isDarwin = nixpkgs.lib.hasSuffix "darwin" system;
          home = (if isDarwin then "/Users/" else "/home/") + vars.user;
        in
        vars
        // {
          inherit system isDarwin home;
          repoDir = "${home}/${vars.repo}";
        };
      darwinVars = varsFor vars.darwinSystem;
      linuxVars = varsFor vars.linuxSystem;
    in
    {
      darwinConfigurations.${vars.host} = nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit self inputs;
          vars = darwinVars;
        };
        modules = [
          ./modules/darwin
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = {
                inherit inputs;
                vars = darwinVars;
              };
              users.${vars.user} = import ./modules/home;
            };
          }
        ];
      };

      # Linux: home-manager switch --flake ~/.config/nix
      homeConfigurations.${vars.user} = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = vars.linuxSystem;
          config.allowUnfree = true;
        };
        extraSpecialArgs = {
          inherit inputs;
          vars = linuxVars;
        };
        modules = [ ./modules/home ];
      };
    };
}
