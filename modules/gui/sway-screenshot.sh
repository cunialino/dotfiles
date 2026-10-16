#!/usr/bin/env bash
#
# sway-screenshot -- interactive region capture for sway.
#
#   sway-screenshot        # slurp a region, save it, put it on the clipboard
#
# The shot lands in $SCREENSHOT_DIR (default ~/pics) as
# screen_<YYYYmmdd-HHMMSS>.png and the very same PNG goes to the clipboard, so
# it can be pasted straight into a chat without hunting for the file.
#
# Esc (or Ctrl-C) in slurp cancels: nothing is written and the clipboard is left
# alone.
#
# sway's `exec` inherits whatever PATH sway itself happened to get, so the store
# paths used here are substituted at build time by modules/gui.

set -uo pipefail

PATH="@EXTRA_PATH@:$PATH"

dir="${SCREENSHOT_DIR:-$HOME/pics}"
if ! mkdir -p "$dir"; then
  printf 'sway-screenshot: cannot create %s\n' "$dir" >&2
  exit 1
fi

# A cancelled slurp prints nothing, and `grim -g ''` means "the whole screen" --
# so an empty geometry has to stop here instead of grabbing everything.
geom=$(slurp) || exit 0
[ -n "$geom" ] || exit 0

file="$dir/screen_$(date +%Y%m%d-%H%M%S).png"

# One capture, two destinations: tee fills the file, wl-copy the clipboard.
if ! grim -g "$geom" - | tee "$file" | wl-copy; then
  printf 'sway-screenshot: capture of %s failed\n' "$geom" >&2
  exit 1
fi
