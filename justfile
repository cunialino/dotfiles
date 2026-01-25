set shell := ["bash", "-c"]

nodes := "elcunal:192.168.0.3 opizero3:192.168.0.4 hp_1:192.168.0.5"

update-all:
    #!/usr/bin/env bash
    for pair in {{nodes}}; do
        IFS=':' read -r name ip <<< "$pair"
        just update-node "$name" "$ip"
    done

update-node name ip:
    @echo ">>> Updating {{name}}"
    kubectl cordon {{name}}
    kubectl drain {{name}} --ignore-daemonsets --delete-emptydir-data --force
    nixos-rebuild switch --flake .#{{name}} \
    --target-host elia@{{ip}} \
    --ask-sudo-password

    ssh elia@{{ip}} "sudo reboot" || true
    
    @echo ">>> Waiting for {{name}} to reboot..."
    sleep 5s
    until $(ssh -o ConnectTimeout=2 -o BatchMode=yes elia@{{ip}} "exit" 2>/dev/null); do sleep 5s; done
    
    ssh -t elia@{{ip}} "sudo nix-collect-garbage -d"
    kubectl uncordon {{name}}
    @echo ">>> {{name}} updated and uncordoned"
