#!/usr/bin/env bash
set -e
# @describe Fetch and extract clean readable text from a webpage. Use after ddg_search to read a full result.
# @option --url!         Full URL of the webpage to fetch (must start with http:// or https://)
# @option --start-index  Character offset to start reading from, for pagination [default: 0]
# @option --max-length   Maximum number of characters to return [default: 8000]

main() {
  body=$(jq -n \
    --arg url "$argc_url" \
    --argjson start "${argc_start_index:-0}" \
    --argjson max "${argc_max_length:-8000}" \
    '{url: $url, start_index: $start, max_length: $max}')

  curl -s -X POST "https://mcpo.tail2f38ea.ts.net/ddg-search/fetch_content" \
    -H "Content-Type: application/json" \
    -d "$body" >> "$LLM_OUTPUT"
}

eval "$(argc --argc-eval "$0" "$@")"
