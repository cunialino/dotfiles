{
  modulesPath,
  pkgs,
  ...
}:

{
  imports = [
    modulesPath
  ];

  config = {
    modules = {
      nvim.enable = true;
      core.enable = true;
      term.enable = true;
      gui.enable = false;
      tmux.enable = true;
      ai.enable = true;
    };
    home.packages = with pkgs; [
      awscli2
    ];
    home.sessionVariables = {
      SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
      REQUESTS_CA_BUNDLE = "/etc/ssl/certs/ca-certificates.crt";
      CURL_CA_BUNDLE = "/etc/ssl/certs/ca-certificates.crt";
      TMPDIR="/home/d00f192.linux/tmp";
    };
    home.username = "d00f192";
    home.homeDirectory = "/home/d00f192.linux";
    home.stateVersion = "25.05";
  };
}
