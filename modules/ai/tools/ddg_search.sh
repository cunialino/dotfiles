#!/usr/bin/env bash
set -e
# @describe Search the web using DuckDuckGo.
# @option --query!       Search query
# @option --max-results  Number of results 1-20 [default: 10]
# @option --region       Region code e.g. us-en [default: ""]

main() {
  body=$(jq -n \
    --arg q "$argc_query" \
    --arg max "${argc_max_results:-10}" \
    --arg region "${argc_region:-}" \
    '{query:$q, max_results:($max|tonumber), region:$region}')
  curl -sf -X POST "https://mcpo.tail2f38ea.ts.net/ddg-search/search" \
    -H "Content-Type: application/json" \
    -d "$body" >> "$LLM_OUTPUT"
}

eval "$(argc --argc-eval "$0" "$@")"
