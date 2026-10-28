#!/usr/bin/env bash
# On attach: re-source tmux.conf if it, or the nix-generated plugins file (store
# files all have mtime 1970, so compare its store path), changed since the last load.
marker=~/.cache/tmux-config-loaded
conf=~/.config/tmux/tmux.conf
plugins=$(readlink -f ~/.local/share/tmux/plugins.conf 2>/dev/null)
if [ ! -e "$marker" ] || [ "$conf" -nt "$marker" ] || [ "$(cat "$marker")" != "$plugins" ]; then
  tmux source-file "$conf" && tmux display-message "tmux config reloaded"
fi
