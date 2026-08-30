{
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
      opencode.enable = true;
      pi-coding-agent.enable = true;
      mcp.enable = true;
      mcp.servers = {
        graphiti.url = "https://graphiti.tail2f38ea.ts.net/mcp";
        k8s-ddg-search.url = "https://ddg.tail2f38ea.ts.net/mcp";
      };
    };

  };
}
