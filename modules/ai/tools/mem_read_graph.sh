#!/usr/bin/env bash
set -e
# @describe Read the entire knowledge graph, returning all entities and relations.

main() {
  curl -s -X POST "https://mcpo.tail2f38ea.ts.net/memory/read_graph" \
    -H "Content-Type: application/json" \
    -d '{}' >> "$LLM_OUTPUT"
}

eval "$(argc --argc-eval "$0" "$@")"
