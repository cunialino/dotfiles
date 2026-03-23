#!/usr/bin/env bash
set -e

# @describe Find contents in directory, files or in outputs.
# Use this when you need to search for regexp and/or keywords in a directory

# @option --regexp! The search query

# @env LLM_OUTPUT=/dev/stdout The output path

main() {
    rg "$argc_path" . >> "$LLM_OUTPUT"
}

eval "$(argc --argc-eval "$0" "$@")"
