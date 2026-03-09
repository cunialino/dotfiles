#!/usr/bin/env bash
set -e
# @describe Delete specific observations from entities in the knowledge graph.
# @option --deletions!  JSON array, each with: entityName (string), observations (string[])
#                       Example: '[{"entityName":"Alice","observations":["old fact"]}]'

main() {
  body=$(jq -n --argjson deletions "$argc_deletions" '{deletions: $deletions}')

  curl -s -X POST "https://mcpo.tail2f38ea.ts.net/memory/delete_observations" \
    -H "Content-Type: application/json" \
    -d "$body" >> "$LLM_OUTPUT"
}

eval "$(argc --argc-eval "$0" "$@")"
