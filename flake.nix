{
  description = "I use Nix btw";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
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
      nixpkgsConfig = {
        allowUnfree = true;
        # ponytail: pnpm 10 has open CVEs, kept only for the pnpm 10 layouts noted in
        # modules/packages.nix. Drop this once those repos move to pnpm 11.
        permittedInsecurePackages = [ "pnpm-10.34.0" ];
      };
    in
    {
      darwinConfigurations.${vars.host} = nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit self inputs;
          vars = darwinVars;
        };
        modules = [
          ./modules/darwin
          { nixpkgs.config = nixpkgsConfig; }
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
          config = nixpkgsConfig;
        };
        extraSpecialArgs = {
          inherit inputs;
          vars = linuxVars;
        };
        modules = [ ./modules/home ];
      };
    };
}
