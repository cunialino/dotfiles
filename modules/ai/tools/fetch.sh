#!/usr/bin/env bash
set -e
# @describe Fetch a URL from the internet and return its contents as markdown.
# @option --url!          URL to fetch
# @option --max-length    Maximum number of characters to return [default: 5000]
# @option --start-index   Start output at this character index, for pagination [default: 0]
# @flag   --raw           Get raw HTML instead of simplified markdown

main() {
  body=$(jq -n \
    --arg url "$argc_url" \
    --argjson max "${argc_max_length:-5000}" \
    --argjson start "${argc_start_index:-0}" \
    --argjson raw "${argc_raw:-false}" \
    '{url: $url, max_length: $max, start_index: $start, raw: $raw}')

  curl -s -X POST "https://mcpo.tail2f38ea.ts.net/fetch/fetch" \
    -H "Content-Type: application/json" \
    -d "$body" >> "$LLM_OUTPUT"
}

eval "$(argc --argc-eval "$0" "$@")"
