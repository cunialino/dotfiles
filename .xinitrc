#!/bin/sh
if [ $# -gt 0 ]; then
  $*
else
  eval $(/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)
  xrdb -merge ~/.Xresources
  [ -f ~/.xprofile ] && . ~/.xprofile
  export SSH_AUTH_SOCK
  xrandr --output eDP-1-1 --primary
  xrandr -output HDMI-1-2 --left-of eDP-1-1
    exec i3 --shmlog-size=26214400
fi

