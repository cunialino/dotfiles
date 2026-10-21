# ---------------------------------------------------------------------------
# ComfyUI -> textfile collector
#
# ComfyUI has no /metrics and upstream has no plan for one; what it does have is
# the JSON its own web UI reads:
#
#   GET /system_stats -> system.{ram_total,ram_free}, devices[].{vram_*,torch_vram_*}
#   GET /prompt       -> exec_info.queue_remaining
#
# Translating those two endpoints here costs one curl pair per interval and no
# custom node inside the container -- the alternative (a third-party exporter
# custom node) would put someone else's Python into the ComfyUI image this host
# pins, and it reports the same numbers.
#
# What it cannot say is *why* ComfyUI is not answering; that is llama-swap's and
# podman's job. And on this APU the "vram" torch reports is the same unified
# pool the amdgpu collector reports as GTT -- cross-check, do not add.
# ---------------------------------------------------------------------------
comfy_url="@COMFY_URL@"

comfy_out="$out_dir/comfyui.prom"
comfy_tmp="$comfy_out.tmp"

stats=$(curl -fsS -m 3 "$comfy_url/system_stats" 2>/dev/null)
queue=$(curl -fsS -m 3 "$comfy_url/prompt" 2>/dev/null)

comfy_up=0
[ -n "$stats" ] && comfy_up=1

{
  echo '# HELP comfyui_up Whether ComfyUI answered /system_stats.'
  echo '# TYPE comfyui_up gauge'
  echo "comfyui_up $comfy_up"

  if [ -n "$queue" ]; then
    echo '# HELP comfyui_queue_remaining Prompts queued and not yet running.'
    echo '# TYPE comfyui_queue_remaining gauge'
    printf '%s' "$queue" \
      | jq -r 'if .exec_info.queue_remaining == null then empty else "comfyui_queue_remaining \(.exec_info.queue_remaining)" end' \
      2>/dev/null
  fi

  if [ -n "$stats" ]; then
    printf '%s' "$stats" | jq -r '
      def sanitize: tostring | gsub("[^A-Za-z0-9_.-]"; "_");
      def opt($v; $metric): if $v == null then empty else "\($metric) \($v)" end;
      def devlabel: "device=\"\(.type | sanitize):\(.index)\",name=\"\(.name | sanitize)\"";
      "# HELP comfyui_info Version strings of the running ComfyUI.",
      "# TYPE comfyui_info gauge",
      "comfyui_info{version=\"\(.system.comfyui_version | sanitize)\",os=\"\(.system.os | sanitize)\"} 1",
      "# HELP comfyui_ram_total_bytes Host RAM total as ComfyUI sees it.",
      "# TYPE comfyui_ram_total_bytes gauge",
      opt(.system.ram_total; "comfyui_ram_total_bytes"),
      "# HELP comfyui_ram_free_bytes Host RAM free as ComfyUI sees it.",
      "# TYPE comfyui_ram_free_bytes gauge",
      opt(.system.ram_free; "comfyui_ram_free_bytes"),
      "# HELP comfyui_device_vram_total_bytes Device memory total as torch reports it.",
      "# TYPE comfyui_device_vram_total_bytes gauge",
      "# HELP comfyui_device_vram_free_bytes Device memory free as torch reports it.",
      "# TYPE comfyui_device_vram_free_bytes gauge",
      "# HELP comfyui_device_torch_vram_free_bytes Free memory inside the torch allocator pool (the number a runaway graph actually runs into).",
      "# TYPE comfyui_device_torch_vram_free_bytes gauge",
      (.devices[]?
        | "comfyui_device_vram_total_bytes{\(devlabel)} \(.vram_total // 0)",
          "comfyui_device_vram_free_bytes{\(devlabel)} \(.vram_free // 0)",
          "comfyui_device_torch_vram_free_bytes{\(devlabel)} \(.torch_vram_free // 0)")
    ' 2>/dev/null
  fi
} >"$comfy_tmp" 2>/dev/null

if [ -s "$comfy_tmp" ]; then
  mv "$comfy_tmp" "$comfy_out"
else
  rm -f "$comfy_tmp"
  echo "comfyui textfile render produced nothing" >&2
  exit 1
fi
