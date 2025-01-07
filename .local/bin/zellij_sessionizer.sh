#! /usr/bin/env bash

LOG_FILE=$HOME/sessionizer.log

LAYOUT=simple

if [ $# -eq 1 ]; then 
  CWD="$1"
else
  CWD=$(fd -d 1 -t d . ~/.config/ ~/builds/ ~/WORK | fzf)
fi

SESSION_NAME="$(basename $CWD)"

if [ ! -z $ZELLIJ ]; then
  zellij pipe -p sessionizer -n sessionizer-new --args cwd=$CWD,name=$SESSION_NAME,layout=$LAYOUT
else
  zellij attach -c $SESSION_NAME options --default-cwd $CWD --default-layout $LAYOUT 
fi

