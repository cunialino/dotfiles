#!/bin/sh
if [ $# -gt 0 ]; then
  "$*"
else
  autorandr horizontal
  xrdb -merge ~/.Xresources
  [ -f ~/.xprofile ] && . "$HOME/.xprofile"
  export SSH_AUTH_SOCK
  exec i3 --shmlog-size=26214400
fi
