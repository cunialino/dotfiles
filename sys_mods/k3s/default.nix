{
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.modules.k3s_node;
  newGroup = "k3s";

  token_file = "/etc/k3s/token";

  extra_flags_common = [
    "--flannel-iface=${cfg.eth}"
  ];

  extra_flags_server = [
    "--write-kubeconfig-mode=640"
    "--write-kubeconfig-group=k3s"
    "--node-ip=${cfg.ip}"
    "--advertise-address=${cfg.ip}"
    "--disable=traefik"

  ]
  ++ extra_flags_common;
  extra_flags_agent = extra_flags_common;
  extra_flags = if cfg.role == "server" then extra_flags_server else extra_flags_agent;
in
{

  options.modules.k3s_node = {
    enable = mkEnableOption "k3s_node";
    main_user = mkOption {
      default = "elia";
      description = "Main user of k3s";
      type = types.str;
    };
    role = lib.mkOption {
      type = types.enum [
        "server"
        "agent"
      ];
      default = "agent";
      description = "Role of this node: either \"server\" (control-plane) or \"agent\" (worker).";
    };

    cluster_init = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Only set true on the bootstrap server to start k3s with --cluster-init for embedded etcd HA.";
    };
    eth = lib.mkOption {
      type = types.str;
      default = "eth0";
      description = "Network interface used by flannel / firewall rules.";
    };

    server_ip = lib.mkOption {
      type = types.str;
      default = "192.168.0.2";
    };

    is_registry = lib.mkOption {
      type = types.bool;
      default = false;
      description = "If true will setup container registries on this machine";
    };

    ip = lib.mkOption {
      type = types.str;
      default = "192.168.0.2";
    };

  };
  config = mkIf config.modules.k3s_node.enable {

    users.users.${cfg.main_user}.extraGroups = [ newGroup ];

    networking.firewall = {

      interfaces = {

        "cni0" = {
          allowedTCPPorts = [
            6443
            10250
          ];
        };

        ${cfg.eth} = {
          allowedTCPPorts = [
            6443
            10256
            10250
          ]
          ++ (
            if cfg.cluster_init then
              [
                5000
                5001
                5002
                5003
              ]
            else
              [ ]
          )
          ++ (
            if cfg.role == "server" then
              [
                2379
                2380
                10257
                10259
              ]
            else
              [ ]
          );
          allowedUDPPorts = [
            8472
          ];
        };
      };
    };

    environment.etc."rancher/k3s/registries.yaml".text = ''
      mirrors:
        docker.io:
          endpoint:
            - "http://${cfg.server_ip}:5001"
        docker.redpanda.com:
          endpoint:
            - "http://${cfg.server_ip}:5001"

        ghcr.io:
          endpoint:
            - "http://${cfg.server_ip}:5002"
        quay.io:
          endpoint:
            - "http://${cfg.server_ip}:5003"
        custom.io:
          endpoint:
            - "http://${cfg.server_ip}:5000"
    '';

    services.k3s = {
      enable = true;
      clusterInit = cfg.cluster_init;
      role = cfg.role;
      extraFlags = extra_flags;
      serverAddr = lib.mkIf (!cfg.cluster_init) "https://${cfg.server_ip}:6443";
      tokenFile = lib.mkIf (!cfg.cluster_init) token_file;
    };

    users.groups.${newGroup} = { };

    virtualisation = lib.mkIf (cfg.is_registry) {
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
      "L /usr/bin/fstrim - - - - /run/current-system/sw/bin/fstrim"
    ];

    services.openiscsi = {
      enable = true;
      name = "${config.networking.hostName}-initiatorhost";
    };
    systemd.services.iscsid.serviceConfig = {
      PrivateMounts = "yes";
      BindPaths = "/run/current-system/sw/bin:/bin";
    };
  };
}
