#!/usr/bin/env bash
set -e
# @describe Open specific nodes in the knowledge graph by their names.
# @option --names!  JSON array of entity name strings to retrieve
#                   Example: '["Alice","Bob"]'

main() {
  body=$(jq -n --argjson names "$argc_names" '{names: $names}')

  curl -s -X POST "https://mcpo.tail2f38ea.ts.net/memory/open_nodes" \
    -H "Content-Type: application/json" \
    -d "$body" >> "$LLM_OUTPUT"
}

eval "$(argc --argc-eval "$0" "$@")"
