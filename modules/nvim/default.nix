{ pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    extraPackages = with pkgs; [ lua-language-server nil nixfmt ];
    extraLuaConfig = ''

    ${builtins.readFile ./conf/init.lua}
    '';

  };
  home.file.".config/nvim/lua".source = ./conf/lua;
  home.file.".config/nvim/lsp".source = ./conf/lsp;
}
