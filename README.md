# Dotfiles

My dotfiles. I just switched them to [home-manager](https://nix-community.github.io/home-manager/).

As of now, home-manager does everything except for:

- nix: I need this to get home-manager in first place
- docker: would be a nightmare due to systemd/runit stuff
- [system requirments](./requirements/README.md)

## Nixos 

I just switched my first machine to nix-os, now the flake manages two things:

- home-manager: I want to keep this for flexibility, so that I can have my dotfiles on non-nixos machines
- nixos: a full on system, which also relies on home-manager for dotfiles.

## Install repo 

```bash
git clone git@github.com:cunialino/dotfiles.git $HOME/builds/dotfiles
cd $HOME/builds/dotfiles
nix run github:nix-community/home-manager/release-25.05 -- switch --flake .#gem
```

## Void-Linux

Session setup:
```bash
sudo usermod -aG _seatd elia
sudo ln -s /etc/sv/seatd/ /var/service
sudo ln -s /etc/sv/chronyd/ /var/service
sudo ln -s /etc/sv/turnstiled/ /var/service
sudo ln -s /etc/sv/bluetoothd/ /var/service
sudo ln -s /etc/sv/ufw/ /var/service
```


## TODO 

There are a couple of things I would still like to improve:

- [ ] make nixgl optional, so that nixos doesn't import that and I only have it on home-manager only gui setups
- [ ] reduce code repetitions for home-manager between hm-only and nixos.
- [ ] abstract common system level stuff for nixos, there are some things I always need and that will be in common between most systems.
- [ ] study a way to make debugpy work when adding it to extraPackages
- [ ] what i did for nvim-treesitter feels really wrong...
