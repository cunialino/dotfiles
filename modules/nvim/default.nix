{ pkgs, ... }: {
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    extraPackages = with pkgs; [ lua-language-server nil nixfmt ];

  };
  home.file.".config/nvim".source = ./conf;
}
