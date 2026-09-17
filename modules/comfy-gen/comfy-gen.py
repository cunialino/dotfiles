#!/usr/bin/env python3
"""Generate an image from a ComfyUI workflow via its REST API.

Runs anywhere that can reach the ComfyUI server (e.g. another PC on the LAN).
Python stdlib only -- no ComfyUI install needed on the machine you run it from.

The workflow is supplied in ComfyUI *API format* -- the same ``Save (API Format)``
export Open WebUI consumes. The canonical copy lives in the ``myai`` repo and is
bundled into the Nix closure at build time (see modules/comfy-gen/default.nix), so
``--workflow workflow.json`` is POSTed as-is: no runtime conversion.

This ROCm build serves outputs at ``/api/view`` rather than the stock ``/file``,
so the download URL below uses that endpoint.

Example (from another PC, server at 192.168.0.6:8188):
    comfy-gen --server http://192.168.0.6:8188 \
        --workflow workflow.json \
        --prompt "a serene alpine lake at sunrise, highly detailed" \
        --out alpine.png
"""

import argparse
import json
import os
import time
import urllib.error
import urllib.request


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


def override(prompt, args):
    if args.prompt is not None:
        for n in prompt.values():
            if n["class_type"] == "CLIPTextEncode" and "text" in n["inputs"]:
                n["inputs"]["text"] = args.prompt
                break
    if args.negative is not None:
        cles = [
            n
            for n in prompt.values()
            if n["class_type"] == "CLIPTextEncode" and "text" in n["inputs"]
        ]
        if cles:
            cles[-1]["inputs"]["text"] = args.negative
    if args.seed is not None:
        seed = int(args.seed)
        # SD3.5/AuraFlow-style workflows drive seeding through a RandomNoise
        # node whose input is ``noise_seed`` (not ``seed``).
        for n in prompt.values():
            if n["class_type"] == "RandomNoise" and "noise_seed" in n["inputs"]:
                n["inputs"]["noise_seed"] = seed
                seed = None
                break
        # Fall back to a KSampler-style ``seed`` input if the workflow uses one.
        if seed is not None:
            for n in prompt.values():
                if n["class_type"] in SAMPLER_TYPES and isinstance(
                    n["inputs"].get("seed"), int
                ):
                    n["inputs"]["seed"] = seed
                    break
    if args.steps is not None:
        for n in prompt.values():
            if n["class_type"] == "BetaSamplingScheduler" and "steps" in n["inputs"]:
                n["inputs"]["steps"] = int(args.steps)
                break
    if args.cfg is not None:
        for n in prompt.values():
            if n["class_type"] == "CFGGuider" and "cfg" in n["inputs"]:
                n["inputs"]["cfg"] = float(args.cfg)
                break
    if args.width and args.height:
        for n in prompt.values():
            if n["class_type"] == "EmptySD3LatentImage" and "width" in n["inputs"]:
                n["inputs"]["width"] = int(args.width)
                n["inputs"]["height"] = int(args.height)
                break


def main():
    ap = argparse.ArgumentParser(
        description="Generate an image from a ComfyUI workflow via API."
    )
    ap.add_argument("--server", default="http://192.168.0.6:8188")
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
    ap.add_argument("--steps", type=int)
    ap.add_argument("--cfg", type=float)
    ap.add_argument("--width", type=int)
    ap.add_argument("--height", type=int)
    ap.add_argument("--out", default="output.png")
    ap.add_argument("--poll", type=int, default=5, help="seconds between history polls")
    args = ap.parse_args()
    args.server = args.server.rstrip("/")

    if args.list:
        list_workflows()
        return
    if not args.workflow:
        print("error: --workflow is required (or use --list to see bundled names)")
        raise SystemExit(1)

    # The bundled workflow is already in ComfyUI API format (node-id keyed),
    # so it is used directly -- no object_info conversion required.
    wf = json.load(open(resolve_workflow(args)))
    override(wf, args)

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
