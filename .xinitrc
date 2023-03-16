#!/bin/sh
if [ $# -gt 0 ]; then
  $*
else
  xrdb -merge ~/.Xresources
  [ -f ~/.xprofile ] && . ~/.xprofile
  export SSH_AUTH_SOCK
  xrandr --output eDP-1-1 --primary
  xrandr -output HDMI-1-2 --left-of eDP-1-1
  setxkbmap it
  exec i3 --shmlog-size=26214400
fi
