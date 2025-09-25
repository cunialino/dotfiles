{
  lib,
  k3s_role,
  main_user,
  eth,
  k3s_labels ? { },
  ...
}:
let
  newGroup = "k3s";

  server_ip = "192.168.0.2";
  token_file = "/etc/k3s/token";

  extra_flags_server = [
    "--write-kubeconfig-mode=640"
    "--write-kubeconfig-group=k3s"
    "--node-ip=${server_ip}"
    "--advertise-address=${server_ip}"
    "--flannel-iface=${eth}"
  ];
  registryPort = 5000;
  registryAddr = "${server_ip}:${toString registryPort}";
  attrToStr = name: "--node-label ${name}=${toString (k3s_labels.${name})}";
  labels_list = builtins.map attrToStr (builtins.attrNames k3s_labels);
  extra_flags_agent = [ "--flannel-iface=${eth}" ] ++ labels_list;
in
{

  users.users.${main_user}.extraGroups = [ newGroup ];

  networking.firewall = {

    interfaces = {
      ${eth} = {
        allowedTCPPorts = [
          6443
          10250
        ]
        ++ (if k3s_role == "server" then [ registryPort ] else [ ]);
        allowedUDPPorts = [ 8472 ];
      };
    };
  };

  environment.etc."rancher/k3s/registries.yaml".text = ''
    mirrors:
      docker.io:
        endpoint:
          - "http://${registryAddr}"
  '';

  services.k3s = {
    enable = true;
    clusterInit = lib.mkIf (k3s_role == "server") true;
    role = k3s_role;
    extraFlags = if k3s_role == "server" then extra_flags_server else extra_flags_agent;
    serverAddr = lib.mkIf (k3s_role == "agent") "https://${server_ip}:6443";
    tokenFile = lib.mkIf (k3s_role == "agent") token_file;
  };

  users.groups.${newGroup} = { };

  virtualisation = lib.mkIf (k3s_role == "server") {
    containers = {
      enable = true;
    };
    podman = {
      enable = true;

      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };
    oci-containers.backend = "podman";
    oci-containers.containers = {
      registry = {
        image = "docker.io/library/registry:3";
        autoStart = true;
        ports = [ "5000:5000" ];

        environment = {
          REGISTRY_VERSION = "0.1";
          REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY = "/var/lib/registry";
          REGISTRY_HTTP_ADDR = ":5000";
          REGISTRY_PROXY_REMOTEURL = "https://registry-1.docker.io";
          REGISTRY_PROXY_TTL = "168h";
        };

        volumes = [
          "/var/lib/registry:/var/lib/registry:Z"
        ];
      };
    };
  };
}
