#!/usr/bin/env bash

set -euo pipefail

case "${1:-}" in
  -o|--open) mode=open ;;
  -l|--launcher) mode=launch ;;
  *) echo "Usage: ${0##*/} {-l|--launcher|-o|--open} [--] [files...]" >&2; exit 1 ;;
esac
shift
if [[ "${1:-}" == -- ]]; then shift; fi

# One editor per multiplexer session, shared by the editor and Yazi panes.
# Zellij takes precedence when it is nested inside tmux.
if [[ -n "${ZELLIJ_SESSION_NAME:-}" ]]; then
  session="zellij:$ZELLIJ_SESSION_NAME"
elif [[ -n "${TMUX:-}" ]]; then
  # The last field of $TMUX is not a reliable current session identifier.
  session="tmux:${TMUX%%,*}:$(tmux display-message -p -t "${TMUX_PANE:?}" '#{session_id}')"
else
  if [[ "$mode" == launch ]]; then
    exec nvim "$@"
  fi
  echo "Open an editor with 'n' in the same tmux or Zellij session first." >&2
  exit 1
fi

socket_dir="${XDG_RUNTIME_DIR:-/tmp}/nvim-$UID"
(umask 077; mkdir -p "$socket_dir")
# Hash session names to keep Unix socket paths short and filesystem-safe.
session_hash=$(printf '%s' "$session" | sha256sum)
socket="$socket_dir/${session_hash:0:24}.sock"

if [[ "$mode" == launch ]]; then
  exec nvim --listen "$socket" "$@"
fi

if [[ $# -eq 0 ]]; then
  echo "No files supplied to the Neovim opener." >&2
  exit 1
fi
if [[ ! -S "$socket" ]]; then
  echo "No Neovim server in this session. Start it with 'n' first." >&2
  exit 1
fi

# Use RPC rather than --remote: --remote starts a local editor when the
# server is unavailable, hanging a non-interactive Yazi shell command.
# Resolve paths in Yazi's cwd, and quote them as Vim strings before fnameescape.
files=()
for file in "$@"; do
  if [[ "$file" != /* ]]; then file="$PWD/$file"; fi
  files+=("'${file//\'/\'\'}'")
done
file_list=$(IFS=,; printf '%s' "${files[*]}")
nvim --server "$socket" --remote-expr \
  "execute('drop ' . join(map([$file_list], 'fnameescape(v:val)'), ' '))" >/dev/null
