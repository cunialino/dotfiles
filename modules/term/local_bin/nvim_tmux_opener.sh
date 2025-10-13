#!/usr/bin/env bash

LOGS=~/.cache/nvimserver.txt

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--open)
      OPENER="TRUE"
      shift
    ;;
    -l|--launcher) 
      LAUNCHER="TRUE"
      shift
    ;;
    -*|--*)
      echo "Unkown option"
      exit 1
    ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
    ;;
  esac
done 

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

NVIM_OPTS=""

if [[ -n "$OPENER" ]]; then
  echo "[$(date)] STARTING OPENER WITH ARGS: $@" | tee $LOGS
  NVIM_MODE="--server"
  NVIM_OPTS="--remote"
elif [[ -n "$LAUNCHER" ]]; then
  echo "[$(date)] STARTING LAUCHER WITH ARGS: $@" | tee $LOGS
  NVIM_MODE="--listen"
  NVIM_OPTS=""
else
  echo "[$(date)] WRONG" | tee $LOGS
fi


if [[ -z "$TMUX" ]]; then 
  echo "[$(date)] NOT IN TMUX" | tee $LOGS
  nvim "$@"
else
  session_id=$(echo "$TMUX" | cut -d "," -f 3)
  if [[ -z "$session_id" ]]; then
    echo "[$(date)] cannot find session"
    exit 1
  else
    nvim "$NVIM_MODE" ~/.cache/nvim/nvim_tmux_"$session_id".pipe "$NVIM_OPTS" "$@"
    if [[ -n "$LAUNCHER" ]]; then
      rm ~/.cache/nvim/nvim_tmux_"$session_id".pipe
    fi
  fi
fi
