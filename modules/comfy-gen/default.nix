{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.comfy-gen;

  # Workflows bundled into the closure so every host that has comfy-gen also
  # has them locally -- no copy needed at run time.
  comfyWorkflowsDir =
    pkgs.runCommand "comfy-gen-workflows" {} ''
      mkdir -p $out
      cp ${./workflow-template.json} $out/
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
        # Workflows shipped in the Nix closure (see comfyWorkflowsDir above).
        export COMFY_WORKFLOWS="${comfyWorkflowsDir}"
        exec ${pkgs.python3} "${pkgs.writeText "comfy-gen.py" (builtins.readFile ./comfy-gen.py)}" "$@"
      '';
    };
in
{
  options.modules.comfy-gen.enable = lib.mkEnableOption "comfy-gen";
  config = lib.mkIf cfg.enable {
    home.packages = [ comfyGen ];
  };
}
