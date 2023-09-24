#!/bin/sh

my_dir="$HOME/X11/"
sys_dir="/etc/X11/"
cd "$my_dir/xorg.conf.d" || exit
for f in *.conf; do
  sudo ln -sf "$(pwd)/$f" "$sys_dir/xorg.conf.d/$f"
  sudo ln -sf "$(pwd)/$f" "$sys_dir/nvidia-xorg.conf.d/$f"
done

cd "$my_dir/nvidia-xorg.conf.d" || exit
for f in *.conf; do
  sudo ln -sf "$(pwd)/$f" "$sys_dir/nvidia-xorg.conf.d/$f"
done

sudo ln -sf "$my_dir/nvidia-xinitrc" "$sys_dir/xinit/nvidia-xinitrc"
