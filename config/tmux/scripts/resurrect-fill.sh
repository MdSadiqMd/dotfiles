#!/usr/bin/env bash
# resurrect records a pane's command only when it runs under a shell. After each save,
# fill in panes created directly with nvim/vim (e.g. `tmux new-window nvim .`).
dir=$(tmux show -gqv @resurrect-dir)
dir=${dir:-$HOME/.tmux/resurrect} # resurrect's own default
dir=${dir/#\~/$HOME}
file="$dir/$(readlink "$dir/last")"
[ -f "$file" ] || exit 0
fills=$(tmux list-panes -a -F '#{session_name}	#{window_index}	#{pane_index}	#{pane_start_command}' |
  awk -F'\t' '$4 ~ /^"?n?vim( |"|$)/ { gsub(/"/, "", $4); print }' OFS='\t')
[ -n "$fills" ] || exit 0
awk -F'\t' -v OFS='\t' 'NR == FNR { cmd[$1 FS $2 FS $3] = $4; next }
  $1 == "pane" && $11 == ":" && (($2 FS $3 FS $6) in cmd) { $11 = ":" cmd[$2 FS $3 FS $6] } { print }' \
  <(printf '%s\n' "$fills") "$file" >"$file.tmp" && mv "$file.tmp" "$file"
