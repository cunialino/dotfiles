# ---------------------------------------------------------------------------
# amdgpu -> textfile collector
#
# Two sources, on purpose:
#
#   * sysfs (mem_info_*, gpu_busy_percent) -- the driver's own counters. A plain
#     file read: it does not touch the render node, so these lines survive an
#     amdgpu_top failure and cost nothing.
#   * amdgpu_top (-J) -- what sysfs does not have: per-IP activity (GRBM), the
#     clocks, and the per-process breakdown (fdinfo). Reading GRBM is also what
#     keeps the GPU out of its deepest sleep states; on a box that is either
#     serving or deliberately idle, that is the price of "is the iGPU busy".
#
# Units are converted to base units (bytes, hertz, W, degC); amdgpu_top reports
# MiB / MHz / W / C.
#
# On this machine (gfx1151 / Radeon 8060S, an APU) "GPU memory" IS the unified
# pool and the driver accounts for it in GTT: gtt_total is the whole GPU-usable
# aperture (~124 GiB with amdgpu.gttsize=126976), while vram_total is the 1 GiB
# visible BAR. Chart gtt_used -- an exporter that reads only mem_info_vram_*
# reports 190 MiB used while 98 GiB of weights are resident.
# ---------------------------------------------------------------------------
card_dir="@CARD_DIR@"
card="@CARD@"

read_sysfs() { cat "$1" 2>/dev/null || true; }

gtt_total=$(read_sysfs "$card_dir/mem_info_gtt_total")
gtt_used=$(read_sysfs "$card_dir/mem_info_gtt_used")
vram_total=$(read_sysfs "$card_dir/mem_info_vram_total")
vram_used=$(read_sysfs "$card_dir/mem_info_vram_used")
vis_vram_total=$(read_sysfs "$card_dir/mem_info_vis_vram_total")
vis_vram_used=$(read_sysfs "$card_dir/mem_info_vis_vram_used")
preempt_used=$(read_sysfs "$card_dir/mem_info_preempt_used")
busy_percent=$(read_sysfs "$card_dir/gpu_busy_percent")

gpu_json=$(timeout 10 amdgpu_top -J -n 1 2>/dev/null)
if [ -n "$gpu_json" ]; then
  gpu_top_up=1
else
  gpu_top_up=0
fi

# One jq pass over the snapshot. Two kinds of output:
#   * metric lines, which go into the file as they are;
#   * PROCS rows (pid, comm, gtt, vram) as TSV, because the per-process metrics
#     also need /proc: the owning systemd unit and the RSS. Those rows are
#     filtered back out below and never reach the file.
activity_metrics=""
proc_rows=""
sensor_metrics=""
if [ "$gpu_top_up" = 1 ]; then
  gpu_flat=$(printf '%s' "$gpu_json" | jq -r --arg card "$card" '
    def sanitize: tostring | gsub("[^A-Za-z0-9_.-]"; "_");
    .devices[] as $d
    # per-IP activity from GRBM: GFX / MediaEngine / Memory
    | (($d.gpu_activity // {}) | to_entries[]
        | select(.value.value != null)
        | "amdgpu_ip_busy_percent{card=\"\($card)\",ip=\"\(.key | ascii_downcase | sanitize)\"} \(.value.value)"),
    # clocks, temperatures and power from the driver sensors
    (($d.Sensors // {}) as $s
      | (
          def value($k; $scale): ($s[$k].value // null) as $v | if $v == null then empty else ($v * $scale) end;
          def emit($name; $label; $v): if $v == null then empty else "\($name){card=\"\($card)\",\($label)} \($v)" end;
          emit("amdgpu_clock_hz"; "clock=\"gfx\""; value("GFX_SCLK"; 1000000)),
          emit("amdgpu_clock_hz"; "clock=\"mem\""; value("GFX_MCLK"; 1000000)),
          emit("amdgpu_clock_hz"; "clock=\"soc\""; value("FCLK"; 1000000)),
          emit("amdgpu_temperature_celsius"; "sensor=\"edge\""; value("Edge Temperature"; 1)),
          emit("amdgpu_temperature_celsius"; "sensor=\"junction\""; value("Junction Temperature"; 1)),
          emit("amdgpu_temperature_celsius"; "sensor=\"memory\""; value("Memory Temperature"; 1)),
          emit("amdgpu_power_watts"; "source=\"average\""; value("Average Power"; 1)),
          emit("amdgpu_power_watts"; "source=\"gfx\""; value("GFX Power"; 1)),
          emit("amdgpu_power_watts"; "source=\"input\""; value("Input Power"; 1))
        )),
    # one row per process holding a DRM fd
    # the snapshot process itself shows up holding 2 MiB: a short-lived
    # artefact of reading the counters, not a workload. No apostrophes anywhere
    # inside this jq program -- it is passed in single quotes, so one would end
    # the argument (and bash -n in writeShellScript is what catches that).
    (($d.fdinfo // {}) | to_entries[]
      | select(.value.usage.usage != null)
      | select((.value.name // "") != "amdgpu_top")
      | [ "PROCS",
          (.key | tostring),
          ((.value.name // "unknown") | sanitize),
          (((.value.usage.usage.GTT.value // 0) * 1048576) | tostring),
          (((.value.usage.usage.VRAM.value // 0) * 1048576) | tostring)
        ] | @tsv)
  ' 2>/dev/null)
  activity_metrics=$(printf '%s\n' "$gpu_flat" | grep -v '^PROCS' || true)
  proc_rows=$(printf '%s\n' "$gpu_flat" | grep '^PROCS' || true)
fi

amdgpu_out="$out_dir/amdgpu.prom"
amdgpu_tmp="$amdgpu_out.tmp"

{
  echo '# HELP amdgpu_up Whether the driver memory counters under sysfs were readable.'
  echo '# TYPE amdgpu_up gauge'
  echo "amdgpu_up{card=\"$card\"} 1"

  echo '# HELP amdgpu_exporter_up Whether amdgpu_top returned a snapshot. Per-IP activity, clocks and per-process memory depend on it.'
  echo '# TYPE amdgpu_exporter_up gauge'
  echo "amdgpu_exporter_up{card=\"$card\"} $gpu_top_up"

  echo '# HELP amdgpu_gtt_total_bytes Total GTT: on an APU the GPU-usable slice of system RAM, i.e. the real memory budget.'
  echo '# TYPE amdgpu_gtt_total_bytes gauge'
  echo "amdgpu_gtt_total_bytes{card=\"$card\"} ${gtt_total:-0}"

  echo '# HELP amdgpu_gtt_used_bytes GTT in use -- on a unified-memory AMD this is where model weights land.'
  echo '# TYPE amdgpu_gtt_used_bytes gauge'
  echo "amdgpu_gtt_used_bytes{card=\"$card\"} ${gtt_used:-0}"

  echo '# HELP amdgpu_vram_total_bytes Total visible VRAM BAR (1 GiB on an APU; not the memory pool).'
  echo '# TYPE amdgpu_vram_total_bytes gauge'
  echo "amdgpu_vram_total_bytes{card=\"$card\"} ${vram_total:-0}"

  echo '# HELP amdgpu_vram_used_bytes Visible VRAM BAR in use.'
  echo '# TYPE amdgpu_vram_used_bytes gauge'
  echo "amdgpu_vram_used_bytes{card=\"$card\"} ${vram_used:-0}"

  echo '# HELP amdgpu_vis_vram_total_bytes Total VRAM visible to the CPU.'
  echo '# TYPE amdgpu_vis_vram_total_bytes gauge'
  echo "amdgpu_vis_vram_total_bytes{card=\"$card\"} ${vis_vram_total:-0}"

  echo '# HELP amdgpu_vis_vram_used_bytes VRAM visible to the CPU in use.'
  echo '# TYPE amdgpu_vis_vram_used_bytes gauge'
  echo "amdgpu_vis_vram_used_bytes{card=\"$card\"} ${vis_vram_used:-0}"

  echo '# HELP amdgpu_preempt_used_bytes Memory held by the driver for preemption.'
  echo '# TYPE amdgpu_preempt_used_bytes gauge'
  echo "amdgpu_preempt_used_bytes{card=\"$card\"} ${preempt_used:-0}"

  echo '# HELP amdgpu_busy_percent GPU busy, as reported by the driver (gpu_busy_percent).'
  echo '# TYPE amdgpu_busy_percent gauge'
  echo "amdgpu_busy_percent{card=\"$card\"} ${busy_percent:-0}"

  [ -n "$activity_metrics" ] && printf '%s\n' "$activity_metrics"

  echo '# HELP amdgpu_process_gtt_bytes GTT held by one process with a DRM file descriptor.'
  echo '# TYPE amdgpu_process_gtt_bytes gauge'
  echo '# HELP amdgpu_process_vram_bytes VRAM BAR held by one process with a DRM file descriptor.'
  echo '# TYPE amdgpu_process_vram_bytes gauge'
  echo '# HELP amdgpu_process_rss_bytes Resident set of a process that holds GPU memory: the host-RAM half of the same allocation on an APU.'
  echo '# TYPE amdgpu_process_rss_bytes gauge'

  if [ -n "$proc_rows" ]; then
    printf '%s\n' "$proc_rows" | while IFS=$'\t' read -r _tag pid comm gtt vram; do
      [ -n "$pid" ] || continue
      unit=$(awk -F '/' '/^0::/ { print $NF }' "/proc/$pid/cgroup" 2>/dev/null | tr -cd 'A-Za-z0-9_.-')
      [ -n "$unit" ] || unit="unknown"
      rss=$(awk '/^VmRSS:/ { print $2 * 1024 }' "/proc/$pid/status" 2>/dev/null)
      labels="card=\"$card\",pid=\"$pid\",comm=\"$comm\",unit=\"$unit\""
      echo "amdgpu_process_gtt_bytes{$labels} ${gtt:-0}"
      echo "amdgpu_process_vram_bytes{$labels} ${vram:-0}"
      echo "amdgpu_process_rss_bytes{$labels} ${rss:-0}"
    done
  fi
} >"$amdgpu_tmp" 2>/dev/null

# Atomic replace: the textfile collector must never see half a file, and a
# failed render keeps the previous snapshot instead of an empty one.
if [ -s "$amdgpu_tmp" ]; then
  mv "$amdgpu_tmp" "$amdgpu_out"
else
  rm -f "$amdgpu_tmp"
  echo "amdgpu textfile render produced nothing" >&2
  exit 1
fi
