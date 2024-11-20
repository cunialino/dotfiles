#!/bin/bash

swaymsg exit &>/dev/null  # Exit existing sway session if running
WLR_BACKENDS=headless WLR_LIBINPUT_NODEVICE=1 WAYLAND_DISPLAY=wayland-1 sway &>/dev/null &
sleep 2
WLR_BACKENDS=headless WLR_LIBINPUT_NODEVICE=1 WAYLAND_DISPLAY=wayland-1 wayvnc --keyboard it 127.0.0.1 &>/dev/null &
echo "SSH tunnel and remote VNC server started."
