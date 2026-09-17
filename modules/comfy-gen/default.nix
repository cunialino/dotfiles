{
  config,
  lib,
  pkgs,
  myai,
  ...
}:
let
  cfg = config.modules.comfy-gen;

  # The canonical ComfyUI workflows live in the ``myai`` repo, where they are
  # also consumed by Open WebUI (base/openwebui/config-env.yaml -> COMFYUI_*).
  # We pull those single sources here and bundle the API-format JSON into the
  # closure, so comfy-gen and Open WebUI never drift apart. Simple user-facing
  # names (see workflowNames) map to those env keys.
  py = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);

  # Simple, user-facing names for the workflows bundled from the myai repo. The
  # canonical copies live there (base/openwebui/config-env.yaml) and are also
  # consumed by Open WebUI, so this is the single source of truth.
  workflowNames = {
    "image-gen" = "COMFYUI_WORKFLOW";      # ComfyUI image generation
    "image-edit" = "IMAGES_EDIT_COMFYUI_WORKFLOW";  # ComfyUI image edit
  };

  comfyWorkflowsDir =
    pkgs.runCommand "comfy-gen-workflows" {
      nativeBuildInputs = [ py ];
    } ''
      mkdir -p $out
      ${py}/bin/python3 - "${myai}/base/openwebui/config-env.yaml" "$out" <<'PY'
      import sys, json, yaml
      outdir = sys.argv[2]
      data = yaml.safe_load(open(sys.argv[1]))["data"]
      for name, key in ${builtins.toJSON workflowNames}.items():
          if key not in data:
              print(f"skipping {name}: {key} not found in config-env.yaml")
              continue
          raw = data[key]
          with open(f"{outdir}/{name}.json", "w") as f:
              json.dump(json.loads(raw), f, indent=2, ensure_ascii=False)
      PY
    '';

  # Drives the running ComfyUI (comfyui-rocm) over its REST API: queues a
  # workflow, waits for completion, and downloads the result. Works from any
  # machine that can reach the server. This ROCm build serves outputs at
  # /api/view rather than the stock /file endpoint.
  comfyGen =
    pkgs.writeShellApplication {
      name = "comfy-gen";
      runtimeInputs = [ pkgs.python3 ];
      text = ''
        # Bundled API-format workflow (extracted from the myai repo, see
        # comfyWorkflowsDir above). comfy-gen.py POSTs it to ComfyUI as-is.
        export COMFY_WORKFLOWS="${comfyWorkflowsDir}"
        exec ${pkgs.python3}/bin/python3 "${pkgs.writeText "comfy-gen.py" (builtins.readFile ./comfy-gen.py)}" "$@"
      '';
    };
in
{
  options.modules.comfy-gen.enable = lib.mkEnableOption "comfy-gen";
  config = lib.mkIf cfg.enable {
    home.packages = [ comfyGen ];
  };
}
