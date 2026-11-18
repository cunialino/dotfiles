{
  config,
  lib,
  pkgs,
  myai,
  ...
}:
let
  cfg = config.modules.comfy-gen;

  # Open WebUI's env ConfigMap in the ``myai`` repo is the canonical home of the
  # ComfyUI workflows -- the app is deployed from
  # clusters/homelab/apps/openwebui. builtins.path so a myai layout change fails
  # at eval time with the path in the message, not as a Python traceback halfway
  # through a system rebuild.
  configEnv = builtins.path {
    path = myai + "/clusters/homelab/apps/openwebui/config-env.yaml";
    name = "openwebui-config-env.yaml";
  };

  py = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);

  # Simple, user-facing names for the workflows bundled from the myai repo, mapped
  # to the Open WebUI env keys that carry them.
  workflowNames = {
    "image-gen" = "COMFYUI_WORKFLOW";      # ComfyUI image generation
    "image-edit" = "IMAGES_EDIT_COMFYUI_WORKFLOW";  # ComfyUI image edit
  };

  comfyWorkflowsDir =
    pkgs.runCommand "comfy-gen-workflows" {
      nativeBuildInputs = [ py ];
    } ''
      mkdir -p $out
      ${py}/bin/python3 - "${configEnv}" "$out" <<'PY'
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
  # workflow, waits for completion, and downloads the result. ComfyUI is reached
  # through llama-swap's /comfyui passthrough, so this works from any machine that
  # can reach the swap -- and starting ComfyUI is the swap's job, not the client's.
  # This ROCm build serves outputs at /api/view rather than the stock /file.
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
