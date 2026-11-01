#!/usr/bin/env python3
"""Generate an image from a ComfyUI workflow via its REST API.

Runs anywhere that can reach llama-swap (e.g. another PC on the LAN). Python
stdlib only -- no ComfyUI install needed on the machine you run it from.

llama-swap owns the ComfyUI process, so nothing here needs root, and by default
the whole session -- queueing, history, the finished image -- goes to
``<swap>/comfyui``, the swap's dedicated passthrough for the ``comfyui_auto``
row. That is the default for two reasons, not merely the way to start the thing:
a request on a path llama-swap does not ignore *is* the start request, and
starting ComfyUI is what evicts whatever model holds the GPU, which no
unprivileged client can arrange any other way; and this box does not publish
:8188 on the LAN while it does publish 11434, so the swap is the only route that
works off the box at all. ``--server`` opts out and speaks to ComfyUI directly,
in which case the swap is used only to start it. Browsers take the same route as
the default and open ``http://<host>:11434/comfyui/``, so their tab is visible
to the scheduler too.

The workflow is supplied in ComfyUI *API format* -- the same ``Save (API Format)``
export Open WebUI consumes. The canonical copy lives in the ``myai`` repo and is
bundled into the Nix closure at build time (see modules/comfy-gen/default.nix), so
``--workflow workflow.json`` is POSTed as-is: no runtime conversion.

This ROCm build serves outputs at ``/api/view`` rather than the stock ``/file``,
so the download URL below uses that endpoint.

Example (llama-swap on the GPU box is the default endpoint):
    comfy-gen --prompt "a serene alpine lake at sunrise, highly detailed" \
        --out alpine.png

The same render against a ComfyUI that is already up, nothing proxied:
    comfy-gen --server http://192.168.0.6:8188 --out alpine.png
"""

import argparse
import json
import os
import threading
import time
import urllib.error
import urllib.request

# llama-swap fronts the whole GPU box, so it is the only address a client needs.
DEFAULT_SWAP = "http://192.168.0.6:11434"

# The swap's passthrough for the comfyui_auto row: the prefix is stripped and the
# query string kept, so ComfyUI's own paths work unchanged behind it.
COMFY_PREFIX = "/comfyui"


def http_get(server, path, timeout=120):
    with urllib.request.urlopen(server + path, timeout=timeout) as r:
        return r.read()


def list_workflows():
    """Print the simple names of the workflows bundled in the Nix closure."""
    bundled = os.environ.get("COMFY_WORKFLOWS")
    if not bundled or not os.path.isdir(bundled):
        print("no bundled workflows available")
        raise SystemExit(1)
    names = sorted(f[:-len(".json")] for f in os.listdir(bundled) if f.endswith(".json"))
    if not names:
        print("no bundled workflows available")
        raise SystemExit(1)
    print("bundled workflows:")
    for n in names:
        print(f"  {n}")


def resolve_workflow(args):
    """Resolve the workflow, in order:
    1. bundled in the Nix closure (COMFY_WORKFLOWS) -- present on every host
       with comfy-gen, so no copy is needed; referred to by simple name
       (e.g. ``image-gen``), ``.json`` optional;
    2. a local path given on the CLI.
    """
    bundled = os.environ.get("COMFY_WORKFLOWS")
    if bundled and os.path.isdir(bundled):
        # Nix may prefix the stored file with a content hash, e.g.
        # <hash>-image-gen.json, so match by suffix. The CLI name may omit
        # the trailing ``.json``.
        target = os.path.basename(args.workflow)
        if target.endswith(".json"):
            target = target[:-len(".json")]
        target += ".json"
        matches = [
            f for f in os.listdir(bundled) if f == target or f.endswith("-" + target)
        ]
        if matches:
            local = os.path.join(bundled, matches[0])
            print(f"using bundled workflow: {local}")
            return local
    if os.path.exists(args.workflow):
        return args.workflow
    print(f"workflow not found: {args.workflow}")
    print("run with --list to see bundled workflow names")
    raise SystemExit(1)


def comfy_is_up(server):
    """One short probe on /system_stats, the endpoint this backend answers 200 on
    only once the server really is up. Through the swap it is itself a start
    request, abandoned after 3 s; ``wake`` below is the one held open."""
    try:
        http_get(server, "/system_stats", timeout=3)
        return True
    except (urllib.error.URLError, OSError):
        return False


def _wake_request(url):
    """Throwaway start request. The answer is a web page nobody asked for and a
    failure here is not this thread's problem: either llama-swap starts the model
    or the caller's readiness poll runs out."""
    try:
        http_get(url, "", timeout=1200)
    except Exception:
        pass


def wake(swap):
    """Start ComfyUI through llama-swap and do not wait on the response: /comfyui/
    holds the request until the container answers, and all it returns is the web
    UI. Readiness is watched on ComfyUI itself instead."""
    print(f"  asking {swap}{COMFY_PREFIX}/ to start it "
          "(evicts whatever model the swap has loaded)")
    threading.Thread(
        target=_wake_request, args=(swap + COMFY_PREFIX + "/",), daemon=True
    ).start()


def ensure_running(args):
    """Guarantee a ComfyUI to talk to, starting it through llama-swap if needed.
    Same procedure on both routes: the readiness probe is pointed at wherever the
    session runs (the swap by default), and one long-lived request is fired at the
    swap so a start survives the probe being abandoned at 3 s."""
    print(f"comfyui endpoint: {args.server}")
    if comfy_is_up(args.server):
        return
    if args.no_wake:
        print(f"error: no ComfyUI at {args.server}, and --no-wake was given.")
        print(f"  start it with:  curl {args.swap}{COMFY_PREFIX}/ &")
        raise SystemExit(1)
    t0 = time.time()
    wake(args.swap)
    while time.time() - t0 < args.wake_timeout:
        if comfy_is_up(args.server):
            print(f"  up after {time.time() - t0:.0f}s")
            return
        time.sleep(5)
    print(f"error: ComfyUI did not come up at {args.server} in {args.wake_timeout}s "
          f"(swap said nothing either; look at: journalctl -u podman-comfyui.service)")
    raise SystemExit(1)


def http_json(server, path, obj=None, timeout=600):
    url = server + path
    if obj is None:
        return json.loads(http_get(server, path))
    req = urllib.request.Request(
        url, data=json.dumps(obj).encode(), headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())


SAMPLER_TYPES = {
    "RandomNoise",
    "KSampler",
    "KSamplerAdvanced",
    "SamplerCustom",
    "SamplerCustomAdvanced",
}

# Text-encode node types whose prompt text lives in different input keys
# (``text`` for the classic CLIP encoders, ``prompt`` for Qwen-2.1 image
# encoders). ``override()`` matches on any of these keys so a single --prompt
# works across workflow schemas.
TEXT_ENCODERS = {
    "CLIPTextEncode",
    "CLIPTextEncodeFlux",
    "TextEncodeQwenImage21",
}
TEXT_INPUT_KEYS = ("text", "prompt")


def override(prompt, args):
    prompt_node = None
    if args.prompt is not None:
        for n in prompt.values():
            if n["class_type"] in TEXT_ENCODERS:
                for key in TEXT_INPUT_KEYS:
                    if key in n["inputs"]:
                        n["inputs"][key] = args.prompt
                        prompt_node = n
                        break
                break
    if args.negative is not None:
        # Pick a distinct encoder node from the positive prompt. Qwen-2.1 image
        # encoders share one prompt input for their positive/negative outputs,
        # so with a single encoder the negative prompt is a no-op rather than
        # clobbering the positive one.
        cles = [
            n
            for n in prompt.values()
            if n["class_type"] in TEXT_ENCODERS
            and any(key in n["inputs"] for key in TEXT_INPUT_KEYS)
        ]
        non_prompt = [n for n in cles if n is not prompt_node]
        chosen = non_prompt[-1] if non_prompt else None
        if chosen is not None:
            for key in TEXT_INPUT_KEYS:
                if key in chosen["inputs"]:
                    chosen["inputs"][key] = args.negative
                    break
    if args.seed is not None:
        seed = int(args.seed)
        # SD3.5/AuraFlow-style workflows drive seeding through a RandomNoise
        # node whose input is ``noise_seed`` (not ``seed``).
        for n in prompt.values():
            if n["class_type"] == "RandomNoise" and "noise_seed" in n["inputs"]:
                n["inputs"]["noise_seed"] = seed
                seed = None
                break
        # Fall back to a sampler-style seed/noise_seed input. Both KSampler
        # (``seed``) and SamplerCustom (``noise_seed``) exist across schemas;
        # only rewrite when the value is a literal int, i.e. not already linked
        # from a RandomNoise node.
        if seed is not None:
            for n in prompt.values():
                if n["class_type"] in SAMPLER_TYPES:
                    for key in ("noise_seed", "seed"):
                        if isinstance(n["inputs"].get(key), int):
                            n["inputs"][key] = seed
                            break
                    break
    if args.width and args.height:
        for n in prompt.values():
            if n["class_type"] in (
                "EmptySD3LatentImage",
                "EmptyLatentImage",
            ) and "width" in n["inputs"]:
                n["inputs"]["width"] = int(args.width)
                n["inputs"]["height"] = int(args.height)
                break


def main():
    ap = argparse.ArgumentParser(
        description="Generate an image from a ComfyUI workflow via API."
    )
    ap.add_argument("--swap", default=os.environ.get("LLAMA_SWAP") or DEFAULT_SWAP,
                    help="llama-swap base URL; ComfyUI is reached through its "
                    "/comfyui passthrough (default %(default)s, or $LLAMA_SWAP)")
    ap.add_argument("--server", help="ComfyUI URL to use directly rather than through "
                    "the swap. Only worth it when ComfyUI is already up and reachable "
                    "to you: this box does not publish :8188, and the swap starts it")
    ap.add_argument("--no-wake", action="store_true",
                    help="fail if ComfyUI is down instead of asking llama-swap for it. "
                    "Needs --server: a proxied request is a start request, so there is "
                    "nothing to skip on the default route")
    ap.add_argument("--wake-timeout", type=int, default=600,
                    help="seconds to wait for llama-swap to bring ComfyUI up")
    ap.add_argument(
        "-l",
        "--list",
        action="store_true",
        help="list the bundled workflows and exit",
    )
    ap.add_argument(
        "--workflow",
        help="simple name of a bundled workflow (see --list), or a local path to the workflow JSON",
    )
    ap.add_argument("--prompt", help="override the positive prompt")
    ap.add_argument("--negative", help="override the negative prompt")
    ap.add_argument("--seed", type=int)
    ap.add_argument("--width", type=int)
    ap.add_argument("--height", type=int)
    ap.add_argument("--out", default="output.png")
    ap.add_argument("--poll", type=int, default=5, help="seconds between history polls")
    args = ap.parse_args()
    args.swap = args.swap.rstrip("/")
    args.server = args.server.rstrip("/") if args.server else args.swap + COMFY_PREFIX

    if args.list:
        list_workflows()
        return
    if not args.workflow:
        print("error: --workflow is required (or use --list to see bundled names)")
        raise SystemExit(1)
    if args.no_wake and args.server == args.swap + COMFY_PREFIX:
        print("error: --no-wake needs --server: every request through llama-swap is a")
        print("  start request, so the default route cannot ask about ComfyUI without it.")
        raise SystemExit(1)

    # The bundled workflow is already in ComfyUI API format (node-id keyed),
    # so it is used directly -- no object_info conversion required.
    # Resolve the graph before waking anything: a bad --workflow should not cost
    # whoever was holding the GPU their model.
    wf = json.load(open(resolve_workflow(args)))
    override(wf, args)

    ensure_running(args)

    res = http_json(args.server, "/prompt", {"prompt": wf, "outputs": {}})
    if "prompt_id" not in res:
        print("ERROR:", json.dumps(res)[:500])
        raise SystemExit(1)
    pid = res["prompt_id"]
    print(f"queued {pid} ...")

    for _ in range(1200):  # up to ~1h
        hist = http_json(args.server, f"/history/{pid}")
        outs = hist.get(pid, {}).get("outputs", {})
        if outs:
            break
        time.sleep(args.poll)
    else:
        print("TIMEOUT")
        raise SystemExit(1)

    imgs = []
    for n in outs.values():
        imgs.extend(n.get("images", []))
    if not imgs:
        print("no images in output:", json.dumps(outs)[:500])
        raise SystemExit(1)
    img = imgs[0]
    # This ROCm build serves outputs at /api/view (not the stock /file).
    data = http_get(
        args.server,
        f"/api/view?filename={img['filename']}"
        f"&subfolder={img.get('subfolder', '')}"
        f"&output_type={img.get('output_type', 'output')}",
    )
    with open(args.out, "wb") as f:
        f.write(data)
    print(f"saved {args.out} ({len(data)} bytes) from {img['filename']}")


if __name__ == "__main__":
    main()
