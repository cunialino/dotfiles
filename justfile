set shell := ["bash", "-c"]

nodes := "opizero3:192.168.0.4 elcunal:192.168.0.3 elcunhp1:192.168.0.5"

update-all:
    #!/usr/bin/env bash
    eval $(ssh-agent)
    ssh-add ~/.ssh/id_ed25519
    for pair in {{nodes}}; do
        IFS=':' read -r name ip <<< "$pair"
        just update-node "$name" "$ip"
    done


clean-all:
    #!/usr/bin/env bash
    eval $(ssh-agent)
    ssh-add ~/.ssh/id_rsa
    for pair in {{nodes}}; do
        IFS=':' read -r name ip <<< "$pair"
        just clean-node "$name" "$ip"
    done


cordon-and-drain name:
    kubectl cordon {{name}}
    kubectl drain {{name}} --ignore-daemonsets --delete-emptydir-data --timeout=180s \
       --pod-selector='longhorn.io/component!=instance-manager' || true


update-node name ip: ( cordon-and-drain name )
    @echo ">>> Updating {{name}} {{ip}}"
    nixos-rebuild switch --flake .#{{name}} \
    --target-host elia@{{ip}} \
    --ask-sudo-password

    ssh elia@{{ip}} "sudo reboot" || true
    
    @echo ">>> Waiting for {{name}} to reboot..."
    sleep 5s
    until $(ssh -o ConnectTimeout=2 elia@{{ip}} "exit 0" 2>/dev/null); do sleep 15s; done
    
    kubectl uncordon {{name}}
    @echo ">>> {{name}} updated and uncordoned"

update-gem: ( cordon-and-drain "elcungem" )
  sudo nixos-rebuild switch --flake .#elcungem

clean-node name ip:
    ssh -t elia@{{ip}} "sudo nix-collect-garbage -d"

run-cmd-all cmd:
    #!/usr/bin/env bash
    for pair in {{nodes}}; do
        IFS=':' read -r name ip <<< "$pair"
        ssh -t elia@"$ip" {{cmd}}
    done

nixrebuild-all:
  #!/usr/bin/env bash
  sudo nixos-rebuild switch --flake .#elcungem
  eval $(ssh-agent)
  ssh-add ~/.ssh/id_rsa
  for pair in {{nodes}}; do
    IFS=':' read -r name ip <<< "$pair"
    nixos-rebuild switch --flake .#"$name" \
    --target-host elia@"$ip" \
    --ask-sudo-password
  done
