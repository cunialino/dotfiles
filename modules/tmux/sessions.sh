#! /usr/bin/env bash

if [ $# -eq 1 ]; then 
  CWD="$1"
else
  CWD=$(fd -d 1 -t d . ~/.config/ ~/builds/ ~/WORK | fzf)
fi

SESSION_NAME="$(basename $CWD)"

if [[ -z $TMUX ]]; then
  tmux new-session -A -s "$SESSION_NAME" -c "$CWD"
else
  tmux has-session -t "$SESSION_NAME" 2>/dev/null
  if [[ $? != 0 ]]; then
    tmux new-session -d -s "$SESSION_NAME" -c "$CWD"
  fi

  tmux switch-client -t "$SESSION_NAME"
fi

