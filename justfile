macos := if os() == "macos" { "true" } else { "" }
treefmt := "nix shell --inputs-from . nixpkgs#treefmt nixpkgs#nixfmt nixpkgs#shfmt nixpkgs#stylua nixpkgs#prettier nixpkgs#taplo -c treefmt"
apply := if macos == "true" { "sudo darwin-rebuild switch --flake .#$(nix eval --raw --file vars.nix host)" } else { "home-manager switch --flake ." }
sudo-once := if macos == "true" { "sudo -v; (while sleep 50; do kill -0 $$ 2>/dev/null || exit; sudo -n true; done) 2>/dev/null &" } else { "" }

default:
    @just --list

fmt:
    {{ treefmt }}

# Evaluate both systems without building: catches removed packages and bad options
check:
    nix eval .#darwinConfigurations.$(nix eval --raw --file vars.nix host).system.drvPath
    nix eval .#homeConfigurations.$(nix eval --raw --file vars.nix user).activationPackage.drvPath

# Apply the config: install what was added, remove what was deleted; versions stay pinned
update:
    #!/usr/bin/env bash
    set -euo pipefail
    {{ sudo-once }}
    {{ apply }}

# Upgrade everything: newer flake.lock, apply it, then upgrade Homebrew packages
rebuild:
    #!/usr/bin/env bash
    set -euo pipefail
    {{ sudo-once }}
    nix flake update
    {{ apply }}
    {{ if macos == "true" { "export HOMEBREW_NO_ASK=1 HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1; brew update --quiet && brew upgrade" } else { "true" } }}

# Edit encrypted secrets (the first run writes a key backup outside the repo)
secrets:
    #!/usr/bin/env bash
    set -euo pipefail
    export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
    # Passphrase-protected backup; kept out of the repo so it never gets published.
    backup="$HOME/.config/sops/age/backup.age"
    if [ ! -f "$backup" ]; then
        echo "Choose a passphrase for the key backup; a new machine asks for it once."
        nix shell --inputs-from . nixpkgs#age -c age -p -a -o "$backup" "$SOPS_AGE_KEY_FILE"
    fi
    nix shell --inputs-from . nixpkgs#sops -c sops secrets/secrets.yaml
    echo "Run 'just update' to apply."

# Encrypt a file (or stdin) into secrets.yaml and verify it; `just update` puts it in place
secret-add name file="-":
    #!/usr/bin/env bash
    set -euo pipefail
    export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
    tmp=$(mktemp)
    trap 'rm -f "$tmp"' EXIT
    chmod 600 "$tmp"
    cat "{{ file }}" >"$tmp"
    nix shell --inputs-from . nixpkgs#sops nixpkgs#jq -c sh -c '
      jq -Rs . <"$1" | sops set --value-stdin secrets/secrets.yaml "[\"$2\"]" &&
        sops decrypt --extract "[\"$2\"]" secrets/secrets.yaml | cmp -s - "$1"
    ' sh "$tmp" "{{ name }}" && echo "{{ name }}: stored and verified" || {
        echo "{{ name }}: round trip failed" >&2
        exit 1
    }
