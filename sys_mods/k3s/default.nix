{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.modules.k3s_node;
  newGroup = "k3s";
  token_file = "/etc/k3s/token";
  kubeVipRbac = pkgs.fetchurl {
    url = "https://kube-vip.io/manifests/rbac.yaml";
    sha256 = "sha256-aK1Jr2air67M4vXHWUzq39Un7Rrz3DkVjIKcZ6xvxkI=";
  };

  # Template the DaemonSet based on official documentation logic
  kubeVipManifest = pkgs.writeText "kube-vip.yaml" ''
    apiVersion: v1
    kind: Pod
    metadata:
      creationTimestamp: null
      name: kube-vip
      namespace: kube-system
    spec:
      containers:
      - args:
        - manager
        env:
        - name: vip_arp
          value: "true"
        - name: port
          value: "6443"
        - name: vip_interface
          value: "${cfg.eth}"
        - name: cp_enable
          value: "true"
        - name: cp_namespace
          value: kube-system
        - name: vip_ddns
          value: "false"
        - name: svc_enable
          value: "true"
        - name: vip_leaderelection
          value: "true"
        - name: vip_leaseduration
          value: "5"
        - name: vip_renewdeadline
          value: "3"
        - name: vip_retryperiod
          value: "1"
        - name: address
          value: "${cfg.kube_vip_ip}"
        image: ghcr.io/kube-vip/kube-vip:v0.8.0
        imagePullPolicy: Always
        name: kube-vip
        resources: {}
        securityContext:
          capabilities:
            add:
            - NET_ADMIN
            - NET_RAW
            - SYS_TIME
        volumeMounts:
        - mountPath: /etc/kubernetes/admin.conf
          name: kubeconfig
      hostAliases:
      - hostnames:
        - kubernetes
        ip: 127.0.0.1
      hostNetwork: true
      volumes:
      - hostPath:
          path: /etc/rancher/k3s/k3s.yaml
        name: kubeconfig
    status: {}
  '';
in
{

  options.modules.k3s_node = {
    enable = mkEnableOption "k3s_node";
    kube_vip_ip = lib.mkOption {
      type = types.str;
      default = "192.168.0.100"; # Choose an IP in your range
      description = "The Virtual IP for the K3s Control Plane.";
    };
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
    wlp = lib.mkOption {
      type = types.str;
      default = "wlp4s0";
      description = "Network interface used to leave cluster.";
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
    dnsServers = lib.mkOption {
      type = types.listOf types.str;
      default = [
        "1.1.1.1"
        "1.0.0.1"
      ];
      description = "DNS servers for k3s pods to use";
    };

  };
  config = mkIf config.modules.k3s_node.enable {

    environment.systemPackages =
      with pkgs;
      [
        bpftools
        bpftrace
      ]
      ++ lib.optionals cfg.cluster_init [
        kubernetes-helm
        cilium-cli
      ];

    users.users.${cfg.main_user}.extraGroups = [ newGroup ];
    networking.firewall = {
      interfaces."${cfg.eth}" = {
        allowedTCPPorts = [
          9100
          6443
          2112
          4240
          4244
          10250
          10256
        ]
        ++ (
          if cfg.cluster_init then
            [
              5000
              5001
              5002
              5003
              5004
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
          53
          123
          51820
          4240
          8472
        ];
      };

      trustedInterfaces = [
        "lxc*"
        "cilium_host"
        "cilium_net"
      ];
    };

    environment.etc."k3s-resolv.conf".text = ''
      ${concatMapStringsSep "\n" (ns: "nameserver ${ns}") cfg.dnsServers}
      options ndots:5
    '';

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
        registry.k8s.io:
          endpoint:
            - "http://${cfg.server_ip}:5004"
        custom.io:
          endpoint:
            - "http://${cfg.server_ip}:5000"
    '';

    environment.etc."rancher/k3s/config.yaml".text = ''
      ${if cfg.cluster_init then "cluster-init: true" else ""}
      ${if cfg.role == "server" then "write-kubeconfig-mode: 640" else ""}
      ${if cfg.role == "server" then "write-kubeconfig-group: k3s" else ""}
      ${if cfg.role == "server" then "flannel-backend: \"none\"" else ""}
      ${if cfg.role == "server" then "disable-kube-proxy: true" else ""}
      ${if cfg.role == "server" then "tls-san:\n  - ${cfg.kube_vip_ip}" else ""}
      ${if cfg.role == "server" then "disable-network-policy: true" else ""}
      kubelet-arg:
        - "resolv-conf=/etc/k3s-resolv.conf"
      node-ip: ${cfg.ip}
      ${
        if cfg.role == "server" then
          ''
            disable:
              - servicelb
              - traefik
          ''
        else
          ""
      }
    '';

    services.k3s = {
      enable = true;
      clusterInit = cfg.cluster_init;
      role = cfg.role;
      serverAddr = lib.mkIf (!cfg.cluster_init) "https://${cfg.kube_vip_ip}:6443";
      tokenFile = lib.mkIf (!cfg.cluster_init) token_file;
      extraKubeletConfig = {
        kubeReserved = {
          cpu = "200m";
          memory = "256Mi";
        };
        systemReserved =
          if cfg.cluster_init then
            {
              cpu = "4";
              memory = "16Gi";
            }
          else
            {
              cpu = "200m";
              memory = "256Mi";
            };
        evictionHard = {
          "memory.available" = "200Mi";
          "nodefs.available" = "10%";
        };
        evictionSoft = {
          "memory.available" = "500Mi";
          "nodefs.available" = "15%";
        };
        evictionSoftGracePeriod = {
          "memory.available" = "1m30s";
          "nodefs.available" = "1m30s";
        };
        failSwapOn = false;
      };
    };

    users.groups.${newGroup} = { };
    system.activationScripts.createRegistryDirs = ''
      mkdir -p /var/lib/registry/{custom,docker,ghcr,quay,k8s}
      chown -R root:root /var/lib/registry
      chmod -R 755 /var/lib/registry
    '';
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
        registryUi = {
          image = "docker.io/joxit/docker-registry-ui:latest";
          autoStart = true;
          ports = [ "6789:80" ];
          environment = {
            SINGLE_REGISTRY = "false";
            DELETE_IMAGES = "true";
            REGISTRY_URL = "http://192.168.0.2:5000";
          };
        };
        registry = {
          image = "docker.io/library/registry:3";
          autoStart = true;
          ports = [ "5000:5000" ];

          environment = {
            REGISTRY_HTTP_ADDR = ":5000";
            REGISTRY_STORAGE_DELETE_ENABLED = "true";
          };
          volumes = [
            "/var/lib/registry/custom:/var/lib/registry:Z"
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
            "/var/lib/registry/docker:/var/lib/registry:Z"
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
            "/var/lib/registry/ghcr:/var/lib/registry:Z"
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
            "/var/lib/registry/quay:/var/lib/registry:Z"
          ];
        };
        k8sRegistry = {
          image = "docker.io/library/registry:3";
          autoStart = true;
          ports = [ "5004:5000" ];
          environment = {
            REGISTRY_HTTP_ADDR = ":5000";
            REGISTRY_PROXY_REMOTEURL = "https://registry.k8s.io";
          };
          volumes = [
            "/var/lib/registry/k8s:/var/lib/registry:Z"
          ];
        };

      };
    };

    systemd.tmpfiles.rules = [
      (lib.mkIf (
        cfg.role == "server" && cfg.cluster_init
      ) "C /var/lib/rancher/k3s/server/manifests/kube-vip-rbac.yaml 0644 root root - ${kubeVipRbac}")

      (lib.mkIf (
        cfg.role == "server"
      ) "C /var/lib/rancher/k3s/agent/pod-manifests/kube-vip.yaml 0644 root root - ${kubeVipManifest}")
      "L /usr/bin/mount - - - - /run/current-system/sw/bin/mount"
      "L /usr/bin/nsenter - - - - /run/current-system/sw/bin/nsenter"
      "L /usr/bin/fstrim - - - - /run/current-system/sw/bin/fstrim"
      "d /home/${cfg.main_user}/.kube 0700 YOUR_USERNAME users - -"
    ];

    systemd.services.user-kubeconfig-ha = {
      description = "Copy K3s config to user home and set Virtual IP";
      after = [ "k3s.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        SRC="/etc/rancher/k3s/k3s.yaml"
        DEST="/home/${cfg.main_user}/.kube/config"

        # Wait for K3s to generate the source file
        while [ ! -f "$SRC" ]; do sleep 1; done

        # Create the HA version in the user's home
        ${pkgs.gnused}/bin/sed "s/127.0.0.1/${cfg.kube_vip_ip}/g" "$SRC" > "$DEST"

        # Set correct permissions so only your user can read it
        chown ${cfg.main_user}:users "$DEST"
        chmod 600 "$DEST"
      '';
    };

    services.openiscsi = {
      enable = true;
      name = "${config.networking.hostName}-initiatorhost";
    };
    systemd.services.iscsid.serviceConfig = {
      PrivateMounts = "yes";
      BindPaths = "/run/current-system/sw/bin:/bin";
    };
    networking.dhcpcd.denyInterfaces = [
      "cilium_*"
      "lxc*"
      "veth*"
    ];
  };
}
