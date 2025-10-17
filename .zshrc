# Ensure Nix profile bins come first
if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi
export PATH="$HOME/.nix-profile/bin:$PATH"

# Go environment variables
export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"

