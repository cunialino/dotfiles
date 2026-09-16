#!/usr/bin/env python3
"""Generate an image from a ComfyUI workflow via its REST API.

Runs anywhere that can reach the ComfyUI server (e.g. another PC on the LAN).
Python stdlib only -- no ComfyUI install needed on the machine you run it from.

This ROCm build serves outputs at ``/api/view`` rather than the stock ``/file``,
so the download URL below uses that endpoint.

Example (from another PC, server at 192.168.0.6:8188):
    comfy-gen --server http://192.168.0.6:8188 \
        --workflow workflow-template.json \
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


def resolve_workflow(args):
    """Resolve the workflow, in order:
    1. bundled in the Nix closure (COMFY_WORKFLOWS) -- present on every host
       with comfy-gen, so no copy is needed;
    2. a local path given on the CLI.
    """
    bundled = os.environ.get("COMFY_WORKFLOWS")
    if bundled:
        # Nix may prefix the stored file with a content hash, e.g.
        # <hash>-workflow-template.json, so match by suffix.
        target = os.path.basename(args.workflow)
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


def build_prompt(server, wf):
    """Convert a workflow JSON (nodes[]+links[]) into /prompt API format.

    Links are resolved by matching the source output type to the target input
    type, so the prompt stays correct even if the frontend version differs from
    the one the workflow was authored against.
    """
    ordered, type_of, src_out = {}, {}, {}
    for nd in wf["nodes"]:
        info = http_json(server, f"/object_info/{nd['type']}")
        if nd["type"] not in info:
            continue
        spec = info[nd["type"]]
        inp = spec.get("input", {})
        fields = {}
        fields.update(inp.get("required", {}))
        fields.update(inp.get("optional", {}))
        for name, cfg in fields.items():
            type_of[(nd["id"], name)] = (
                cfg[0] if isinstance(cfg, list) else cfg.get("type")
            )
        io = spec.get("input_order", {})
        ordered[nd["id"]] = list(io.get("required", [])) + list(io.get("optional", []))
        src_out[nd["id"]] = spec.get("output", [])

    linked = {nd["id"]: {} for nd in wf["nodes"]}
    for link in wf["links"]:
        _, src_id, src_o, tgt_id, tgt_i, _ = link
        src_type = (
            src_out.get(src_id, [])[src_o]
            if 0 <= src_o < len(src_out.get(src_id, []))
            else None
        )
        names = ordered.get(tgt_id, [])
        name = names[tgt_i] if 0 <= tgt_i < len(names) else None
        if name and src_type:
            ct = type_of.get((tgt_id, name))
            if ct and ct.lower() != src_type.lower():
                for n in names:
                    if (
                        type_of.get((tgt_id, n))
                        and type_of[(tgt_id, n)].lower() == src_type.lower()
                    ):
                        name = n
                        break
        if name:
            linked[tgt_id][name] = [str(src_id), src_o]

    prompt = {}
    for nd in wf["nodes"]:
        info = http_json(server, f"/object_info/{nd['type']}")
        if nd["type"] not in info:
            continue
        widgets = nd.get("widgets_values") or []
        linked_names = set(linked[nd["id"]])
        widget_inputs = [
            n for n in ordered.get(nd["id"], []) if n.lower() not in linked_names
        ]
        inputs = {n: v for n, v in zip(widget_inputs, widgets)}
        for iname, ref in linked[nd["id"]].items():
            inputs[iname] = list(ref)
        prompt[str(nd["id"])] = {
            "class_type": nd["type"],
            "inputs": inputs,
            "properties": nd.get("properties", {}),
        }
    return prompt


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
        for n in prompt.values():
            if n["class_type"] in SAMPLER_TYPES and isinstance(
                n["inputs"].get("seed"), int
            ):
                n["inputs"]["seed"] = int(args.seed)
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
        "--workflow",
        required=True,
        help="local path to the workflow JSON, or the name of a bundled one",
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

    wf = json.load(open(resolve_workflow(args)))
    prompt = build_prompt(args.server, wf)
    override(prompt, args)

    res = http_json(args.server, "/prompt", {"prompt": prompt, "outputs": {}})
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
