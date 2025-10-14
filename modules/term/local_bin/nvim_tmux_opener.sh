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
  echo "[$(date)] STARTING LAUCHER WITH ARGS: $@" | tee -a $LOGS
  NVIM_MODE="--listen"
else
  echo "[$(date)] WRONG" | tee -a $LOGS
  exit 1
fi

if [[ -z "$TMUX" ]]; then 
  echo "[$(date)] NOT IN TMUX" | tee -a $LOGS
  nvim "$NVIM_OPTS"
else
  session_id=$(echo "$TMUX" | cut -d "," -f 3)
  if [[ -z "$session_id" ]]; then
    echo "[$(date)] cannot find session" | tee -a $LOGS
    exit 1
  else
    file=~/.cache/nvim/nvim_tmux_"$session_id".pipe
    nvim $NVIM_MODE $file $NVIM_OPTS "$@"
  fi
fi
