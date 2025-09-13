#!/bin/sh
#
edp=$(xrandr --listactivemonitors | grep -o "eDP[-[:digit:]]\?" | head -1)
hdmi=$(xrandr --listactivemonitors | grep -o "HDMI[-[:digit:]]\?" | head -1)
if [ "$hdmi" != "" ]; then
  xrandr --output "$hdmi" --primary
  xrandr --output "$edp" --left-of "$hdmi"
fi
