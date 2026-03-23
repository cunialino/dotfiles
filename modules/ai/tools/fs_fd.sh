#!/usr/bin/env bash
set -e

# @describe Fine files by name.
# Use this when you need to find a file by partial name.

# @option --search! The partial name the file you want to find

# @env LLM_OUTPUT=/dev/stdout The output path

main() {
    fd "$argc_path" >> "$LLM_OUTPUT"
}

eval "$(argc --argc-eval "$0" "$@")"
