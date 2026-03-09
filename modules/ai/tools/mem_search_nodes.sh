#!/usr/bin/env bash
set -e
# @describe Search for nodes in the knowledge graph by matching entity names, types, and observations.
# @option --query!  Search query string

main() {
  body=$(jq -n --arg query "$argc_query" '{query: $query}')

  curl -s -X POST "https://mcpo.tail2f38ea.ts.net/memory/search_nodes" \
    -H "Content-Type: application/json" \
    -d "$body" >> "$LLM_OUTPUT"
}

eval "$(argc --argc-eval "$0" "$@")"
