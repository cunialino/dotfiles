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

  config.modules = {
    core.enable = true;
    nvim.enable = true;
    term.enable = true;
    tmux.enable = true;
    pi-coding-agent.enable = true;
    comfy-gen.enable = true;

    # Same cluster MCP servers as elcungem, over their kube-vip addresses
    # (myai: base/graphiti -> .201, base/ddg-search -> .202). Plain HTTP on the
    # LAN, no Tailscale on this box and none needed -- pi here is on the LAN
    # permanently (192.168.0.6).
    mcp = {
      enable = true;
      servers = {
        graphiti.url = "http://192.168.0.201:8000/mcp";
        k8s-ddg-search.url = "http://192.168.0.202/mcp";
      };
    };
  };
}
