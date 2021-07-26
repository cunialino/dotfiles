#!/usr/bin/bash
. $(dirname $0)/config
. $(dirname $0)/colors

if pgrep -x "lemonbar" 1>/dev/null 2>/dev/null
then
  echo "Bar Already running"
else
    killall cc.sh
    $HOME/.config/i3/lemonbar/cc.sh | lemonbar -p -f "${font}" > log &
fi
