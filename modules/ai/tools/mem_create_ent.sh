#!/usr/bin/env bash
set -e
# @describe Create multiple new entities in the knowledge graph.
# @option --entities!  JSON array of entities, each with: name (string), entityType (string), observations (string[])
#                      Example: '[{"name":"Alice","entityType":"person","observations":["works at Acme"]}]'

main() {
  body=$(jq -n --argjson entities "$argc_entities" '{entities: $entities}')

  curl -s -X POST "https://mcpo.tail2f38ea.ts.net/memory/create_entities" \
    -H "Content-Type: application/json" \
    -d "$body" >> "$LLM_OUTPUT"
}

eval "$(argc --argc-eval "$0" "$@")"
