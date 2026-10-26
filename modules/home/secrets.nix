{
  config,
  inputs,
  lib,
  pkgs,
  vars,
  ...
}:
let
  sopsFile = ../../secrets/secrets.yaml;
  # Key names in the sops file are plain text: a secret is declared only once it
  # exists (`just secret-add`), so a missing one never breaks decrypting the rest.
  has = name: lib.hasInfix "\n${name}:" ("\n" + builtins.readFile sopsFile);
  home = vars.home;
  ssh = name: {
    "ssh-${name}".path = "${home}/.ssh/${name}";
  };

  # Each one is decrypted at login and on every switch. With a path it is linked
  # there read-only (0400), replacing what was there; without one it stays in
  # ~/.config/sops-nix/secrets/<name> for a tool or template to read.
  secrets = {
    motherduck-token = { };
    opencode-service-password = { };
    github-token = { };
    gpg-signing-key = { };
    opencode-auth.path = "${home}/.local/share/opencode/auth.json";
    solana-keypair.path = "${home}/.config/solana/id.json";
    aws-credentials.path = "${home}/.aws/credentials";
  }
  // lib.mergeAttrsList (
    map ssh [
      "id_ed25519"
      "id_ed25519_sharif"
      "id_ed25519_tailscale"
      "gitlab_key"
      "google_compute_engine"
      "human-archive-temp.pem"
      "timbre-key.pem"
    ]
  );
in
{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  # secrets/secrets.yaml is committed encrypted. The age key comes from
  # ~/.config/sops/age/keys.txt; bootstrap.sh restores it from the passphrase
  # backup at ~/.config/sops/age/backup.age, which is never committed.
  sops = {
    age.keyFile = "${home}/.config/sops/age/keys.txt";
    defaultSopsFile = sopsFile;
    secrets = lib.filterAttrs (name: _: has name) secrets;

    templates =
      # OpenCode's background-service config; it only writes this file when the
      # password is missing or on `opencode service set`. Set the password with
      # `just secrets`, not `opencode service set password`.
      lib.optionalAttrs (has "opencode-service-password") {
        "opencode-service.json" = {
          path = "${config.xdg.configHome}/opencode/service.json";
          content = builtins.toJSON { password = config.sops.placeholder.opencode-service-password; } + "\n";
        };
      }
      # gh reads a token from hosts.yml before the keychain. Read-only: log in
      # again by updating the secret (`gh auth token | just secret-add github-token`
      # after `gh auth login`), not by `gh auth login` alone.
      // lib.optionalAttrs (has "github-token") {
        "gh-hosts.yml" = {
          path = "${config.xdg.configHome}/gh/hosts.yml";
          content = ''
            github.com:
                users:
                    ${vars.githubUser}:
                        oauth_token: ${config.sops.placeholder.github-token}
                git_protocol: https
                oauth_token: ${config.sops.placeholder.github-token}
                user: ${vars.githubUser}
          '';
        };
      };

    # sops-nix needs Go >= 1.26; nixpkgs 25.11 defaults to 1.25 but ships 1.26.
    # ponytail: drop this override once nixpkgs' default go is >= 1.26 (26.05).
    package =
      (import inputs.sops-nix {
        pkgs = pkgs.extend (
          _: prev: {
            go = prev.go_1_26;
            buildGoModule = prev.buildGoModule.override { go = prev.go_1_26; };
          }
        );
      }).sops-install-secrets;
  };

  # A GPG keyring is a database, not a file to link: import the signing key (the
  # one config/git/config names) when it is missing. On macOS sops-nix decrypts in
  # a launchd job that starts during activation, so wait briefly for the file.
  home.activation.importGpgKey = lib.mkIf (has "gpg-signing-key") (
    lib.hm.dag.entryAfter [ "sops-nix" ] ''
      key=${config.sops.secrets.gpg-signing-key.path}
      export PATH="/opt/homebrew/bin:${home}/.nix-profile/bin:$PATH"
      fpr=$(${lib.getExe pkgs.git} config --file ${vars.repoDir}/config/git/config user.signingkey || true)
      for _ in $(seq 50); do [ -r "$key" ] && break; sleep 0.1; done
      if [ -r "$key" ] && [ -n "$fpr" ] && command -v gpg >/dev/null && ! gpg --list-secret-keys "$fpr" >/dev/null 2>&1; then
        run gpg --batch --import "$key"
      fi
    ''
  );

  home.sessionVariables.SOPS_AGE_KEY_FILE = config.sops.age.keyFile;
}
