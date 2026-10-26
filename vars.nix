# Machine-specific values; edit these on a new machine.
{
  user = "sadiq";
  host = "sadiq"; # darwinConfigurations.<host>
  darwinSystem = "aarch64-darwin";
  linuxSystem = "x86_64-linux";
  linuxIsNixOS = false; # true turns off the non-NixOS (genericLinux) shims
  repo = ".config/nix"; # this repo, relative to $HOME
  githubUser = "MdSadiqMd"; # gh login, rendered from the github-token secret
}
