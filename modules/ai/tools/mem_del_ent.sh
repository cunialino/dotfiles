#!/usr/bin/env bash
set -e
# @describe Delete multiple entities and their associated relations from the knowledge graph.
# @option --entity-names!  JSON array of entity name strings to delete
#                          Example: '["Alice","Bob"]'

main() {
  body=$(jq -n --argjson names "$argc_entity_names" '{entityNames: $names}')

  curl -s -X POST "https://mcpo.tail2f38ea.ts.net/memory/delete_entities" \
    -H "Content-Type: application/json" \
    -d "$body" >> "$LLM_OUTPUT"
}

eval "$(argc --argc-eval "$0" "$@")"
