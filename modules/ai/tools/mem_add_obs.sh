#!/usr/bin/env bash
set -e
# @describe Add new observations to existing entities in the knowledge graph.
# @option --observations!  JSON array of observation objects, each with: entityName (string), contents (string[])
#                          Example: '[{"entityName":"Alice","contents":["just got promoted"]}]'

main() {
  body=$(jq -n --argjson observations "$argc_observations" '{observations: $observations}')

  curl -s -X POST "https://mcpo.tail2f38ea.ts.net/memory/add_observations" \
    -H "Content-Type: application/json" \
    -d "$body" >> "$LLM_OUTPUT"
}

eval "$(argc --argc-eval "$0" "$@")"
