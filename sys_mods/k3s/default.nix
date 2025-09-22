{
  k3s_role,
  main_user,
  ...
}:
let
  newGroup = "k3s";
in
{

  users.users.${main_user}.extraGroups = [ newGroup ];

  networking.firewall = {
    interfaces = {
      cni0 = {
        allowedTCPPorts = [
          6443 # kubelet stuff
          10250 # metrics server
        ];
      };
    };
  };
  services.k3s = {
    enable = true;
    role = k3s_role;
    extraFlags = [
      "--write-kubeconfig-mode=640"
      "--write-kubeconfig-group=k3s"
    ];
  };

  users.groups.${newGroup} = { };
}
