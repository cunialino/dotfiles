#!/usr/bin/env bash
set -e
# @describe Create multiple new relations between entities in the knowledge graph. Relations should be in active voice.
# @option --relations!  JSON array of relations, each with: from (string), to (string), relationType (string)
#                       Example: '[{"from":"Alice","to":"Acme","relationType":"works_at"}]'

main() {
  body=$(jq -n --argjson relations "$argc_relations" '{relations: $relations}')

  curl -s -X POST "https://mcpo.tail2f38ea.ts.net/memory/create_relations" \
    -H "Content-Type: application/json" \
    -d "$body" >> "$LLM_OUTPUT"
}

eval "$(argc --argc-eval "$0" "$@")"
