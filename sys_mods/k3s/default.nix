{
  config,
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

  attrToStr = name: "--node-label=${name}=${toString (k3s_labels.${name})}";
  labels_list = builtins.map attrToStr (builtins.attrNames k3s_labels);

  extra_flags_common = [
    "--flannel-iface=${eth}"
  ]
  ++ labels_list;

  extra_flags_server = [
    "--write-kubeconfig-mode=640"
    "--write-kubeconfig-group=k3s"
    "--node-ip=${server_ip}"
    "--advertise-address=${server_ip}"
    "--disable=traefik"

  ]
  ++ extra_flags_common;
  registryPort = 5000;
  registryAddr = "${server_ip}:${toString registryPort}";
  extra_flags_agent = extra_flags_common;
in
{

  users.users.${main_user}.extraGroups = [ newGroup ];

  networking.firewall = {

    interfaces = {

      "cni0" = {
        allowedTCPPorts = [
          6443
          10250
        ];
      };

      ${eth} = {
        allowedTCPPorts = [
          6443
          10250
        ]
        ++ (
          if k3s_role == "server" then
            [
              registryPort
              5001
              5002
              5003
            ]
          else
            [ ]
        );
        allowedUDPPorts = [ 8472 ];
      };
    };
  };

  environment.etc."rancher/k3s/registries.yaml".text = ''
    mirrors:
      docker.io:
        endpoint:
          - "http://${server_ip}:5001"
      docker.redpanda.com:
        endpoint:
          - "http://${server_ip}:5001"

      ghcr.io:
        endpoint:
          - "http://${server_ip}:5002"
      quay.io:
        endpoint:
          - "http://${server_ip}:5003"
      custom.io:
        endpoint:
          - "http://${server_ip}:5000"
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
          REGISTRY_HTTP_ADDR = ":5000";
        };
        volumes = [
          "/var/lib/registry:/var/lib/registry:Z"
        ];
      };

      dockerRegistry = {
        image = "docker.io/library/registry:3";
        autoStart = true;
        ports = [ "5001:5000" ];

        environment = {
          REGISTRY_HTTP_ADDR = ":5000";
          REGISTRY_PROXY_REMOTEURL = "https://registry-1.docker.io";
        };
        volumes = [
          "/var/lib/registry:/var/lib/registry:Z"
        ];
      };

      ghcrRegistry = {
        image = "docker.io/library/registry:3";
        autoStart = true;
        ports = [ "5002:5000" ];
        environment = {
          REGISTRY_HTTP_ADDR = ":5000";
          REGISTRY_PROXY_REMOTEURL = "https://ghcr.io";
        };
        volumes = [
          "/var/lib/registry:/var/lib/registry:Z"
        ];
      };
      quayRegistry = {
        image = "docker.io/library/registry:3";
        autoStart = true;
        ports = [ "5003:5000" ];
        environment = {
          REGISTRY_HTTP_ADDR = ":5000";
          REGISTRY_PROXY_REMOTEURL = "https://quay.io";
        };
        volumes = [
          "/var/lib/registry:/var/lib/registry:Z"
        ];
      };

    };
  };

  systemd.tmpfiles.rules = [
    "L /usr/bin/mount - - - - /run/current-system/sw/bin/mount"
    "L /usr/bin/nsenter - - - - /run/current-system/sw/bin/nsenter"
  ];

  services.openiscsi = {
    enable = true;
    name = "${config.networking.hostName}-initiatorhost";
  };
  systemd.services.iscsid.serviceConfig = {
    PrivateMounts = "yes";
    BindPaths = "/run/current-system/sw/bin:/bin";
  };
}
