# ---------------------------------------------------------------------------
# llama.cpp router -> textfile collector
#
# The router is NOT a scrape target. In llama.cpp GET /metrics is not a
# management endpoint: the body is a server_task_result_metrics, produced by the
# loaded context of ONE instance. The router process runs no context -- it is
# server_models (an instance table with load/evict) plus server_http_proxy -- so
# a /metrics request has to be proxied to an instance, and it names that instance
# with ?model=. Naming a preset is exactly what schedules it (join -> ensure_model
# -> spawn -> load_model), so a scrape per preset boots every preset on every
# interval and models-max evicts the LRU to make room: the box spends the day
# loading and unloading models because a dashboard asked whether they were
# loaded. (Observed: 30 s scrapes, seven presets, `evicting idle LRU name=... for
# a queued request` and `unable to allocate ROCm0 buffer` in a loop.)
#
# Residency is available without asking the router anything. Each instance is a
# llama-server process whose argv carries --alias <preset> and --port <n>, and
# the preset list is the [sections] of the router's own --models-preset file. So
# this collector reads /proc and config.ini, sends no request to the router
# (unless probeModels is on, see below), and costs a directory read per interval.
#
# Metrics:
#   llamacpp_router_up              a process with --models-preset <this file> runs
#   llamacpp_presets_configured     [sections] read from that file (drift signal)
#   llamacpp_preset_loaded{preset}  1 when that instance's process exists
#   llamacpp_preset_child_pid{preset}   its pid, 0 when not resident
#   llamacpp_preset_port{preset}        its port, 0 when not resident
#
# `loaded` is process existence, not readiness: between the router spawning a
# child and that child finishing load_model it reads 1 while it cannot serve.
# Distinguishing the two needs the child's own answer, and the cheap candidate
# (GET :port/health) is deliberately NOT done here: with sleep-idle-seconds set,
# a request to a sleeping child wakes it up, so a 10 s probe loop would keep
# every resident preset warm forever -- the same mistake this collector exists
# to undo. Per-model metrics, readiness included, belong to the instance itself
# on the port reported above, and only while it is resident.
#
# What is lost against scraping: nothing that was true before. Unloaded presets
# reported up == 0 either way; the difference is what it took to find out.
# ---------------------------------------------------------------------------
router_url="@ROUTER_URL@"
config_ini="@CONFIG_INI@"
probe_models="@PROBE_MODELS@"

llamacpp_out="$out_dir/llamacpp.prom"
llamacpp_tmp="$llamacpp_out.tmp"

# The [sections] of config.ini, minus the global [*]. Taking the list from the
# file rather than from the Nix config means a preset added to config.ini shows
# up in the metrics without a rebuild -- and one removed from it stops being
# reported instead of sitting at up == 0 forever, which is how a stale hand-kept
# list reads indistinguishable from a dead target.
presets=""
if [ -r "$config_ini" ]; then
  presets=$(grep -oE '^\[[^]]+\]' "$config_ini" 2>/dev/null | tr -d '[]' | grep -v '^\*$' || true)
fi

# One pass over /proc for both kinds of process: a single grep over every
# cmdline on the box, one tr, one awk. A loop over /proc/[0-9]* would fork twice
# per pid, every interval, to find two or three processes.
#
# The router is the llama-server that was handed this preset file -- not the
# unit's MainPID, which would need systemctl in the collector's PATH for the
# same answer.
#
# Instances are matched on --alias rather than on being children of the router,
# so a re-parented instance is still counted. That is safe because a preset name
# is unique per box and nothing else running llama-server here shares one:
# llama-decision serves d3-nano, which is not a [section] of this file. Two
# instances of one preset cannot happen (the router keeps one process per model);
# if it ever did, the first row wins.
#
# -Z matters: it puts a NUL between the filename and the line instead of a
# colon, so after the tr the path is one field and argv starts at the next. With
# the default separator argv[0] rides along inside the filename field and every
# field after it is off by one.
procs=$(
  grep -a -Z -H -e '--models-preset' -e '--alias' /proc/[0-9]*/cmdline 2>/dev/null \
    | tr '\0' ' ' \
    | awk -v ini="$config_ini" '
        {
          pid = $1
          sub(/^\/proc\//, "", pid)
          sub(/\/cmdline$/, "", pid)
          # Identity comes from comm, the name of the binary itself, rather than
          # from the command line: a shell whose argument text happens to mention
          # these flags (a debugging command, or a test of this very script) must
          # not read as an instance, and the command line is exactly where such
          # text lives. comm cannot say anything but what is executing.
          # No apostrophes in here: the program is passed in single quotes.
          comm_file = "/proc/" pid "/comm"
          if ((getline comm < comm_file) <= 0) { close(comm_file); next }
          close(comm_file)
          if (comm !~ /^llama-server/) next
          alias = ""
          port = ""
          is_router = 0
          for (i = 2; i <= NF; i++) {
            if ($i == "--alias") alias = $(i + 1)
            else if ($i == "--port") port = $(i + 1)
            else if ($i == "--models-preset" && $(i + 1) == ini) is_router = 1
          }
          if (is_router) print "R\t" pid
          if (alias != "") print "I\t" alias "|" pid "|" (port == "" ? 0 : port)
        }
      ' || true
)
router_pid=$(printf '%s\n' "$procs" | awk -F '\t' '$1 == "R" { print $2; exit }')
instances=$(printf '%s\n' "$procs" | awk -F '\t' '$1 == "I" { print $2 }')

{
  echo '# HELP llamacpp_router_up Whether a llama.cpp router process was running with this preset file.'
  echo '# TYPE llamacpp_router_up gauge'
  if [ -n "$router_pid" ]; then
    echo 'llamacpp_router_up 1'
  else
    echo 'llamacpp_router_up 0'
  fi

  echo '# HELP llamacpp_presets_configured Preset sections read from the router preset file.'
  echo '# TYPE llamacpp_presets_configured gauge'
  preset_count=$(printf '%s\n' "$presets" | grep -c . || true)
  echo "llamacpp_presets_configured ${preset_count:-0}"

  echo '# HELP llamacpp_preset_loaded Whether this preset has an instance process now. Read from the process table: unlike a /metrics request that names the preset, observing it does not load it.'
  echo '# TYPE llamacpp_preset_loaded gauge'
  echo '# HELP llamacpp_preset_child_pid Pid of the instance process, 0 when the preset is not resident.'
  echo '# TYPE llamacpp_preset_child_pid gauge'
  echo '# HELP llamacpp_preset_port Loopback port the instance answers on, 0 when not resident. This is the address to scrape for that preset, and only while it is resident.'
  echo '# TYPE llamacpp_preset_port gauge'

  for preset in $presets; do
    row=$(printf '%s\n' "$instances" | awk -F '|' -v p="$preset" '$1 == p { print $2 "|" $3; exit }')
    child=${row%%|*}
    port=${row##*|}
    [ -n "$child" ] || child=0
    [ -n "$port" ] || port=0
    label=$(printf '%s' "$preset" | tr -cd 'A-Za-z0-9_.-')

    if [ "$child" = 0 ]; then
      echo "llamacpp_preset_loaded{preset=\"$label\"} 0"
    else
      echo "llamacpp_preset_loaded{preset=\"$label\"} 1"
    fi
    echo "llamacpp_preset_child_pid{preset=\"$label\"} $child"
    echo "llamacpp_preset_port{preset=\"$label\"} $port"
  done

  # Off by default, and only worth turning on once it has been watched: the
  # instance list is answered by the router itself rather than by proxy (it is
  # part of the /models/load, /models/unload, /models/sse management family),
  # which is what makes it safe. That is a reading of the route table, not a
  # measurement -- check with
  #     journalctl -u llama-cpp --since -1m | grep "join: request"
  # after the first interval: a join line means the request reached the
  # scheduler, and this probe has to go back off.
  if [ "$probe_models" = "true" ]; then
    models=$(curl -fsS -m 3 "$router_url/v1/models" 2>/dev/null)
    [ -n "$models" ] || models=$(curl -fsS -m 3 "$router_url/models" 2>/dev/null)

    models_up=0
    [ -n "$models" ] && models_up=1

    echo '# HELP llamacpp_models_endpoint_up Whether the router answered its own instance list. Diagnostic for probeModels: with any join: request in the router log behind it, switch the probe off.'
    echo '# TYPE llamacpp_models_endpoint_up gauge'
    echo "llamacpp_models_endpoint_up $models_up"

    if [ "$models_up" = 1 ]; then
      echo '# HELP llamacpp_models_reported Instances the router lists, resident or queued. Cross-check against llamacpp_preset_loaded; the process table is the authority.'
      echo '# TYPE llamacpp_models_reported gauge'
      printf '%s' "$models" \
        | jq -r '"llamacpp_models_reported \(((.data // .models // .) | if type == "array" then length else 0 end))"' \
        2>/dev/null
    fi
  fi
} >"$llamacpp_tmp" 2>/dev/null

# Atomic replace, as in the other fragments. Note that no `exit` here on
# purpose: the fragments are concatenated into one shell script, so leaving it
# would skip the fragments that come after this one.
if [ -s "$llamacpp_tmp" ]; then
  mv "$llamacpp_tmp" "$llamacpp_out"
else
  rm -f "$llamacpp_tmp"
  echo "llamacpp textfile render produced nothing" >&2
fi
