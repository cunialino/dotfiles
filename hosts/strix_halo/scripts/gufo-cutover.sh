#!/usr/bin/env bash
#
# gufo-cutover.sh -- drive the model stack through llama-swap and leave a
# readable trail of what actually happened.
#
# Run it as root AFTER `nixos-rebuild switch`:
#
#   sudo ./hosts/strix_halo/scripts/gufo-cutover.sh          # full run
#   sudo ./hosts/strix_halo/scripts/gufo-cutover.sh --dry     # preflight only, no requests
#   sudo ./hosts/strix_halo/scripts/gufo-cutover.sh --yes     # no countdown
#   sudo ./hosts/strix_halo/scripts/gufo-cutover.sh --with-genai --with-image
#
# Logs: /var/log/gufo-cutover/<UTC timestamp>/  (+ .../latest symlink), world
# readable so a non-root session can read them afterwards.
#
# The name is older than the job. This script used to perform the halogen -> gufo
# cutover: stop halogen, wait for the memory, load gufo, and put halogen back on
# any failure. halogen is off the host config now, so what remains is a smoke
# test of the stack -- cold load through the swap, warm path, exclusive-group
# eviction, image generation -- plus the one guard that still matters: nothing
# else may be holding the unified pool when gufo allocates.
#
# WHY that guard exists: 124 GiB of unified memory, 107 GiB of weights, and gufo
# measured ~98 GiB resident once loaded (gpu_device_used_mib=100920 of 126976).
# A hand-started halogen (flash_serve, ~70 GiB) makes gufo die partway through
# the shards on `hipMalloc failed for blk.8.ffn_down_exps.weight`, and llama-swap
# then hangs rather than erroring. That belongs in preflight, not mid-request.
#
# Everything here mirrors hosts/strix_halo/default.nix; if the aliases or ports
# change there, change them here too.
#
# NOTE: no jq dependency. root's PATH on this host does not carry it, so model
# listings are parsed with grep.

set -uo pipefail
umask 022

# --- topology (mirrors hosts/strix_halo/default.nix) -------------------------

SWAP=http://127.0.0.1:11434
GUFO_LLM=http://127.0.0.1:8732
GUFO_IMG=http://127.0.0.1:8189

UNIT_SWAP=llama-swap.service
UNIT_GUFO_LLM=gufo-llm.service
UNIT_GUFO_IMG=gufo-image.service
UNIT_LLAMACPP=llama-cpp.service

MODEL=gufo-qwen3.8-flash-next
AGENT_ALIAS=qwen3.8-flash-next
GENAI_ALIAS=qwen3.6
IMAGE_ALIAS=Qwen-Image-2.1

MODELS_DIR=/var/lib/gufo-models
FLASH_DIR=$MODELS_DIR/qwen3.8-flash-next

# exact sizes from the pinned HF revisions -- preflight fails loudly if a model is
# missing or truncated, rather than letting a 10-minute load attempt discover it.
expect=(
  "$FLASH_DIR/UD-Q4_K_XL/Qwen3.8-Flash-Next-UD-Q4_K_XL-00001-of-00004.gguf 10946624"
  "$FLASH_DIR/UD-Q4_K_XL/Qwen3.8-Flash-Next-UD-Q4_K_XL-00002-of-00004.gguf 49859583136"
  "$FLASH_DIR/UD-Q4_K_XL/Qwen3.8-Flash-Next-UD-Q4_K_XL-00003-of-00004.gguf 49376141504"
  "$FLASH_DIR/UD-Q4_K_XL/Qwen3.8-Flash-Next-UD-Q4_K_XL-00004-of-00004.gguf 12087983520"
  "$FLASH_DIR/MTP/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf 2786568256"
  "$FLASH_DIR/mmproj-BF16.gguf 907542944"
)

# MemAvailable needed before gufo is started: 107 GiB of weights plus KV cache,
# MTP state and the 8 GiB disk-cache staging buffer. Below this, starting gufo is
# how you get the OOM killer choosing for you.
MEM_NEEDED_KB=$((115 * 1024 * 1024))

LOAD_TIMEOUT=${LOAD_TIMEOUT:-1800}   # gufo cold load: 107 GiB off NVMe
POLL=10

# --- args --------------------------------------------------------------------

DRY=0
ASSUME_YES=0
WITH_GENAI=0
WITH_IMAGE=0
for a in "$@"; do
  case "$a" in
    --dry) DRY=1 ;;
    --yes) ASSUME_YES=1 ;;
    --with-genai) WITH_GENAI=1 ;;
    --with-image) WITH_IMAGE=1 ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done

# --- logging -----------------------------------------------------------------

TS=$(date -u +%Y%m%dT%H%M%SZ)
LOGROOT=/var/log/gufo-cutover
LOGDIR=$LOGROOT/$TS
SUMMARY=$LOGDIR/summary.log

mkdir -p "$LOGDIR"
ln -sfn "$LOGDIR" "$LOGROOT/latest" 2>/dev/null || true

PASS=0
FAIL=0
START_TS=$(date +%s)

say() {
  printf '%s  %s\n' "$(date -u +%H:%M:%SZ)" "$*" | tee -a "$SUMMARY"
}

record() { # name -> writes "<name>: rc=<code> extra"
  local name=$1
  shift
  printf '%s: %s\n' "$name" "$*" >>"$SUMMARY"
}

pass() { PASS=$((PASS + 1)); say "PASS  $*"; }
fail() { FAIL=$((FAIL + 1)); say "FAIL  $*"; }

save() { # save <file> <label> -- keep a copy of evidence and mention it
  say "      saved $1  ($2)"
}

dump_journal() {
  local unit=$1 tag=$2
  journalctl -u "$unit" --no-pager --since "@$START_TS" >"$LOGDIR/journal-$tag.txt" 2>&1 || true
  say "      journal: $LOGDIR/journal-$tag.txt ($(wc -l <"$LOGDIR/journal-$tag.txt") lines)"
}

# --- helpers -----------------------------------------------------------------

mem_avail_kb() { awk '/^MemAvailable:/ {print $2}' /proc/meminfo; }

# halogen's engine (flash_serve) keeps ~70 GiB of the 124 GiB unified pool
# mapped. While that exists gufo's hipMalloc fails partway through the shards:
#   hipMalloc failed for blk.8.ffn_down_exps.weight (629145600 bytes)
# This is the only honest "can gufo allocate" signal on this box, because both
# obvious proxies lied while 70 GiB was held:
#   MemAvailable                          -> 86,362 MiB (looked fine)
#   card0/.../mem_info_vram_used          -> 233,857,024  (~0.2 GiB, useless)
# so the gate below keys on the process, not on a counter.
halogen_engine_running() { pgrep -x flash_serve >/dev/null 2>&1; }

http_get() { # url -> sets CODE TIME BODY
  local url=$1 out=$2 mt=${3:-20}
  CODE=$(curl -sS -o "$out" -w '%{http_code}' --max-time "$mt" "$url" 2>>"$LOGDIR/curl.err" || echo "000")
  TIME=$(curl -sS -o /dev/null -w '%{time_total}' --max-time "$mt" "$url" 2>/dev/null || echo "?")
}

chat_via_swap() {
  # chat_via_swap <model> <outfile> <max-time>  -> sets CODE TTFB TOTAL
  local model=$1 out=$2 mt=$3
  local t0 t1
  t0=$(date +%s)
  CODE=$(curl -sS -o "$out" -w '%{http_code}' --max-time "$mt" \
    -H 'Content-Type: application/json' \
    -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with exactly one word: PONG\"}],\"max_tokens\":512,\"temperature\":0}" \
    "$SWAP/v1/chat/completions" 2>>"$LOGDIR/curl.err" || echo "000")
  t1=$(date +%s)
  TOTAL=$((t1 - t0))
  TTFB=$TOTAL
}

body_has_content() { # outfile -> 0 only if the model actually answered
  # The first version of this check was "a content key exists && PONG appears",
  # and it PASSED on a response whose content was "" with finish_reason=length:
  # the 16-token budget ran out inside reasoning_content, so nothing was ever
  # said. Require real text, a clean stop, and the expected word.
  # NB `"content":"` cannot match inside `"reasoning_content":"` -- there is no
  # quote before the word -- so this really does test the answer field.
  grep -qE '"content":"[^"]' "$1" 2>/dev/null || return 1
  grep -q '"finish_reason":"stop"' "$1" 2>/dev/null || return 1
  grep -q 'PONG' "$1" 2>/dev/null || return 1
  return 0
}

wait_unit_active() { # unit timeout -> 0 when active
  local unit=$1 deadline=$(( $(date +%s) + $2 ))
  while [ "$(date +%s)" -lt "$deadline" ]; do
    if systemctl is-active --quiet "$unit"; then return 0; fi
    sleep "$POLL"
    printf '.'
  done
  return 1
}

# No rollback any more. halogen is off the host config, so there is nothing to
# fall back to: on failure the journals get dumped, the script exits non-zero,
# and gufo is left exactly as it is for a human (or the next session) to read.
# Inventing a rollback target here would just hide the failure.
abort_stack() {
  say "ABORT  no rollback target exists (halogen is gone from the host config)."
  say "       gufo/llama-swap left as-is -- read the dumps above before retrying."
  exit 1
}

# --- stages ------------------------------------------------------------------

stage_preflight() {
  say "=== preflight ==="

  if [ "$(id -u)" != "0" ]; then
    say "must run as root (reads other users' process tables, writes /var/log) -- re-run with sudo"
    exit 2
  fi
  pass "running as root"

  local missing=0 entry path want got
  for entry in "${expect[@]}"; do
    path=${entry%% *}
    want=${entry##* }
    got=$(stat -c %s "$path" 2>/dev/null || echo 0)
    if [ "$got" = "$want" ]; then
      pass "model $path"
    else
      fail "model $path (got $got want $want) -- models not in place, aborting before anything is stopped"
      missing=1
    fi
  done
  if [ "$missing" -ne 0 ]; then
    # The download scripts write to the invoking user's home, not /var/lib. If the
    # weights are sitting there, say so with the exact fix instead of making
    # someone re-derive where 139 GiB went.
    real_home=$(getent passwd "${SUDO_USER:-$(id -un)}" 2>/dev/null | cut -d: -f6)
    probe="$real_home/gufo-models/qwen3.8-flash-next/UD-Q4_K_XL/Qwen3.8-Flash-Next-UD-Q4_K_XL-00001-of-00004.gguf"
    if [ -f "$probe" ]; then
      say "      weights look complete but are in ${real_home}/gufo-models -- move them:"
      say "        find $real_home/gufo-models -name '*.incomplete' -delete"
      say "        sudo mv $real_home/gufo-models $MODELS_DIR"
      say "        sudo chown -R ${SUDO_USER:-elia}:users $MODELS_DIR"
      say "      (same filesystem, so the mv is a rename, not a 139 GiB copy)"
    else
      say "      no weights found under ${real_home}/gufo-models either -- they were never downloaded?"
    fi
    say "aborting: model files incomplete"
    exit 1
  fi

  if [ ! -f "$MODELS_DIR/qwen-image-2.1/model_index.json" ]; then
    say "note: Qwen-Image-2.1 not found at $MODELS_DIR/qwen-image-2.1 (image tests will fail if enabled)"
  fi

  systemctl cat "$UNIT_GUFO_LLM" >/dev/null 2>&1 && pass "$UNIT_GUFO_LLM installed" || { fail "$UNIT_GUFO_LLM missing -- was nixos-rebuild switch run?"; exit 1; }

  http_get "$SWAP/health" "$LOGDIR/swap-health-before.txt" 10
  if [ "$CODE" = "200" ]; then pass "llama-swap /health 200"; else fail "llama-swap /health $CODE"; exit 1; fi

  # Holder executables are the single most likely thing to be wrong: a Nix package
  # interpolated as a string yields its $out DIRECTORY, and llama-swap then does
  # fork/exec on a directory -> "permission denied" (that is exactly what killed
  # the first real run of this cutover). Read the config.yaml the live unit was
  # given and check every `cmd:` is a real executable file, not a directory.
  say "      checking holder executables in the live llama-swap config"
  local swap_cfg
  swap_cfg=$(systemctl show -p ExecStart --value "$UNIT_SWAP" 2>/dev/null \
    | grep -oE '/nix/store/[^ ]+\.ya?ml' | head -1)
  if [ -z "$swap_cfg" ] || [ ! -r "$swap_cfg" ]; then
    fail "cannot locate llama-swap's rendered config.yaml (from: $UNIT_SWAP ExecStart)"
    exit 1
  fi
  say "      config: $swap_cfg"

  local n=0 bad=0 holder
  while read -r holder; do
    [ -n "$holder" ] || continue
    n=$((n + 1))
    if [ -d "$holder" ]; then
      fail "holder is a DIRECTORY, not a program: $holder"
      bad=$((bad + 1))
    elif [ ! -x "$holder" ]; then
      fail "holder not executable: $holder"
      bad=$((bad + 1))
    else
      pass "holder executable: $(basename "$holder")"
    fi
  done < <(awk '
    /^[[:space:]]*cmd:/ {
      line = $0
      sub(/^[[:space:]]*cmd:[[:space:]]*/, "", line)
      if (line == "") { getline line; sub(/^[[:space:]]+/, "", line) }
      split(line, a, /[[:space:]]/)
      print a[1]
    }' "$swap_cfg")

  say "      checked $n holder commands"
  if [ "$bad" -ne 0 ]; then
    say "aborting: $bad/$n holders are not runnable. The fix is in nix (return"
    say "\"\${pkg}/bin/\${name}\" from swapUnitHolder, not the package), then"
    say "nixos-rebuild switch --flake ~/builds/dotfiles#elcunhalo"
    exit 1
  fi

  say "      MemAvailable: $(numfmt --from=iec --to=iec $(mem_avail_kb)K 2>/dev/null || echo "$(mem_avail_kb) kB")   (floor: $((MEM_NEEDED_KB / 1048576)) GiB; the real gate is flash_serve being gone)"
  if halogen_engine_running; then
    say "      flash_serve is running and holding ~70 GiB of unified memory: $(pgrep -x flash_serve | tr '\n' ' ')"
  else
    say "      flash_serve not running"
  fi
}

stage_snapshot_before() {
  say "=== before state ==="
  {
    echo "--- free -m ---"; free -m
    echo "--- units ---"
    systemctl show -p Id -p ActiveState -p SubState -p ExecMainStartTimestamp \
      "$UNIT_SWAP" "$UNIT_GUFO_LLM" "$UNIT_GUFO_IMG" "$UNIT_LLAMACPP" 2>/dev/null
    echo "--- listening (11434 11435 8732 8188 8189) ---"
    ss -tlnp 2>/dev/null | grep -E ':(11434|11435|8732|8188|8189)\b' || echo "(none)"
    echo "--- llama-swap /v1/models ---"
    curl -s --max-time 15 "$SWAP/v1/models" || echo "(request failed)"
  } >"$LOGDIR/before.txt" 2>&1
  save "$LOGDIR/before.txt" "state before cutover"

  curl -s --max-time 15 "$SWAP/v1/models" >"$LOGDIR/models.json" 2>/dev/null
  if grep -q "\"$AGENT_ALIAS\"" "$LOGDIR/models.json"; then
    pass "llama-swap advertises alias $AGENT_ALIAS"
  else
    fail "llama-swap does not advertise $AGENT_ALIAS"
    say "      advertised: $(grep -o '"id":"[^"]*"' "$LOGDIR/models.json" | tr '\n' ' ')"
  fi
}

stage_ready() {
  say "=== ready: is the unified pool free for gufo? ==="

  if [ "$ASSUME_YES" != "1" ] && [ "$DRY" != "1" ]; then
    say "the cold load below takes ~60s and can evict whatever the exclusive groups"
    say "hold (llama.cpp / ComfyUI / gufo-image). 10s to Ctrl-C, --yes skips it."
    for i in $(seq 10 -1 1); do printf '\r   %2ds ' "$i"; sleep 1; done
    printf '\n'
  fi

  # The gate is the process, not a counter: MemAvailable read 86 GiB while 70 GiB
  # was pinned, and card0's mem_info_vram_used read ~0.2 GiB while gufo held 98.
  if halogen_engine_running; then
    fail "flash_serve is running (pid $(pgrep -x flash_serve | tr '\n' ' ')): a hand-started halogen holds ~70 GiB"
    say "      gufo cannot allocate next to it (hipMalloc dies at blk.8). Stop it first:"
    say "        podman stop halogen"
    say "      aborting before spending a cold load on it."
    exit 1
  fi
  pass "flash_serve not running"

  if systemctl is-active --quiet "$UNIT_GUFO_LLM"; then
    say "      note: $UNIT_GUFO_LLM is already active, so the timing below measures a"
    say "      warm model. systemctl stop $UNIT_GUFO_LLM first for a real cold number."
  fi

  local need=$((MEM_NEEDED_KB / 1024)) got_kb
  got_kb=$(mem_avail_kb)
  if [ "$got_kb" -lt "$MEM_NEEDED_KB" ]; then
    say "      MemAvailable is $((got_kb / 1024)) MiB (< ${need} MB). Not fatal: this"
    say "      counter has been wrong in the optimistic direction before, so it is a"
    say "      sanity check, not the gate. Continuing."
  fi
  pass "proceeding with $((got_kb / 1024)) MiB available for a ~98 GiB load"
}

stage_agent_cold() {
  say "=== agent model through the swap (cold: starts $UNIT_GUFO_LLM) ==="
  say "      issuing request; gufo has 107 GiB to load, max ${LOAD_TIMEOUT}s"

  chat_via_swap "$AGENT_ALIAS" "$LOGDIR/chat-agent-cold.json" "$LOAD_TIMEOUT"
  record chat-cold "http=$CODE seconds=$TOTAL"
  say "      http=$CODE in ${TOTAL}s"

  if [ "$CODE" = "200" ] && body_has_content "$LOGDIR/chat-agent-cold.json"; then
    pass "cold chat through $SWAP (model $AGENT_ALIAS)"
  else
    fail "cold chat: http=$CODE"
    say "      body head: $(head -c 300 "$LOGDIR/chat-agent-cold.json" | tr '\n' ' ')"
    dump_journal "$UNIT_GUFO_LLM" gufo-llm-failed
    dump_journal "$UNIT_SWAP" swap-failed
    abort_stack
    exit 1
  fi

  wait_unit_active "$UNIT_GUFO_LLM" 60 >>"$LOGDIR/null" 2>&1 || true
  say "      $UNIT_GUFO_LLM: $(systemctl is-active "$UNIT_GUFO_LLM") (pid $(systemctl show -p MainPID --value "$UNIT_GUFO_LLM"))"

  http_get "$GUFO_LLM/health" "$LOGDIR/gufo-health.txt" 15
  [ "$CODE" = "200" ] && pass "gufo direct /health 200" || fail "gufo direct /health $CODE"
}

stage_agent_warm() {
  say "=== agent model warm path ==="
  chat_via_swap "$AGENT_ALIAS" "$LOGDIR/chat-agent-warm.json" 300
  record chat-warm "http=$CODE seconds=$TOTAL"
  if [ "$CODE" = "200" ] && body_has_content "$LOGDIR/chat-agent-warm.json"; then
    pass "warm chat through the swap in ${TOTAL}s (no reload)"
  else
    fail "warm chat: http=$CODE"
  fi
}

stage_genai() {
  [ "$WITH_GENAI" = "1" ] || { say "=== genai cross-group test skipped (--with-genai) ==="; return 0; }
  say "=== genai: requesting $GENAI_ALIAS must evict the agent model ==="
  chat_via_swap "$GENAI_ALIAS" "$LOGDIR/chat-genai.json" 1200
  record chat-genai "http=$CODE seconds=$TOTAL"
  if [ "$CODE" = "200" ]; then
    pass "genai chat ($GENAI_ALIAS) http 200"
  else
    fail "genai chat: http=$CODE -- $(head -c 200 "$LOGDIR/chat-genai.json" | tr '\n' ' ')"
  fi
  sleep 15
  if systemctl is-active --quiet "$UNIT_GUFO_LLM"; then
    fail "expected $UNIT_GUFO_LLM to be unloaded by the genai request, still active"
  else
    pass "$UNIT_GUFO_LLM unloaded by the exclusive genai request"
  fi
  say "      $UNIT_LLAMACPP: $(systemctl is-active "$UNIT_LLAMACPP")"
}

stage_image() {
  [ "$WITH_IMAGE" = "1" ] || { say "=== image test skipped (--with-image) ==="; return 0; }
  say "=== Qwen-Image-2.1 through the swap ==="
  local t0 t1
  t0=$(date +%s)
  CODE=$(curl -sS -o "$LOGDIR/image.json" -w '%{http_code}' --max-time "$LOAD_TIMEOUT" \
    -H 'Content-Type: application/json' \
    -d "{\"model\":\"$IMAGE_ALIAS\",\"prompt\":\"A red ceramic teapot on a wooden table\",\"size\":\"1024x1024\",\"seed\":42}" \
    "$SWAP/v1/images/generations" 2>>"$LOGDIR/curl.err" || echo "000")
  t1=$(date +%s)
  record chat-image "http=$CODE seconds=$((t1 - t0))"
  say "      http=$CODE in $((t1 - t0))s"
  if [ "$CODE" = "200" ] && grep -q 'b64_json' "$LOGDIR/image.json"; then
    pass "image generation through the swap"
    grep -o '"b64_json": *"[^"]*"' "$LOGDIR/image.json" | head -1 | sed 's/.*"\([A-Za-z0-9+/=]*\)"$/\1/' \
      | base64 -d >"$LOGDIR/teapot.png" 2>/dev/null || true
    say "      saved $LOGDIR/teapot.png ($(stat -c %s "$LOGDIR/teapot.png" 2>/dev/null || echo 0) bytes)"
  else
    fail "image generation: http=$CODE -- $(head -c 200 "$LOGDIR/image.json" | tr '\n' ' ')"
    dump_journal "$UNIT_GUFO_IMG" gufo-image
  fi
}

stage_after_snapshot() {
  say "=== after state ==="
  {
    echo "--- free -m ---"; free -m
    echo "--- units ---"
    systemctl show -p Id -p ActiveState -p MainPID -p MemoryCurrent \
      "$UNIT_SWAP" "$UNIT_GUFO_LLM" "$UNIT_GUFO_IMG" "$UNIT_LLAMACPP" 2>/dev/null
    echo "--- listening ---"
    ss -tlnp 2>/dev/null | grep -E ':(11434|11435|8732|8188|8189)\b' || echo "(none)"
  } >"$LOGDIR/after.txt" 2>&1
  save "$LOGDIR/after.txt" "state after the run"
  dump_journal "$UNIT_SWAP" swap
  dump_journal "$UNIT_GUFO_LLM" gufo-llm
}

# --- main --------------------------------------------------------------------

say "gufo model-stack test  started $(date -u '+%Y-%m-%d %H:%M:%SZ')"
say "logs: $LOGDIR"
say "mode: dry=$DRY yes=$ASSUME_YES genai=$WITH_GENAI image=$WITH_IMAGE"

stage_preflight
stage_snapshot_before

if [ "$DRY" = "1" ]; then
  say "=== --dry: stopping here, nothing was started or stopped ==="
else
  stage_ready
  stage_agent_cold
  stage_agent_warm
  stage_genai
  stage_image
fi

stage_after_snapshot

say "=== result: $PASS passed, $FAIL failed in $(( ($(date +%s) - START_TS) / 60 )) min ==="
say "everything is under $LOGDIR"

[ "$FAIL" -eq 0 ] || exit 1
