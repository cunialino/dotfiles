{
  config,
  modulesPath,
  catppuccin,
  ...
}:

{
  imports = [
    modulesPath
    catppuccin.homeModules.catppuccin
  ];

  config = {
    modules = {
      nvim.enable = true;
      core.enable = true;
      term.enable = true;
      gui.enable = true;
      tmux.enable = true;
      bw.enable = true;
      ai.enable = true;
      pi-coding-agent.enable = true;
      mcp.enable = true;
      comfy-gen.enable = true;

      # Agent rig: herdr owns the terminals, pi stays pi. Queue runs serially --
      # one inference unit (llama-swap on the Strix Halo) serves them all anyway.
      herdr = {
        enable = true;
        piIntegration.enable = true;
        # The queue is triggered by timers, so it has to find a server whether or
        # not anyone is logged in (see users.users.elia.linger in default.nix).
        server.startOnLogin = true;
        queue = {
          enable = true;
          # Explicit rather than inherited: an unattended queue should not follow
          # the default model if the interactive default moves.
          defaultModel = "qwen3.8-flash-next";
          defaultBase = "main";
          watch = {
            enable = true;
            # Every repo under here with a tasks/ directory is eligible, including
            # ones cloned after this switch. Serial everywhere: one inference unit.
            roots = [ "${config.home.homeDirectory}/builds" ];
            intervalSecs = 120;
          };
          # Vikunja tasks labelled `agent-in` -> <repo>/tasks/proposed/*.md.
          # Staging on: a planner's proposal only becomes runnable work when a human
          # moves the file into tasks/.
          intake = {
            enable = true;
            root = "${config.home.homeDirectory}/builds";
            model = "llhalo/qwen3.8-flash-next";
            intervalSecs = 600;
            # Only the mappings I am sure about. Anything unmapped and without a
            # `repo:` line gets a comment asking for one, which is cheaper than a
            # wrong guess landing work in someone else's repository.
            projectMap = {
              "Home Lab" = "homelab";
              "Self hosting" = "homelab";
              dotfiles = "dotfiles";
            };
          };
        };
      };

      # MCP servers on the cluster reached through their kube-vip addresses
      # (myai: base/graphiti -> .201, base/ddg-search -> .202) instead of the
      # Tailscale ingresses: plain HTTP on the LAN, no tsnet round trip and no
      # dependency on tailscaled being up. Only reachable from the LAN.
      mcp.servers = {
        graphiti.url = "http://192.168.0.201:8000/mcp";
        k8s-ddg-search.url = "http://192.168.0.202/mcp";
      };
    };

  };
}
