# Dotfiles

My dotfiles. I just switched them to [home-manager](https://nix-community.github.io/home-manager/).

As of now, home-manager does everything except for:

- nix: I need this to get home-manager in first place
- docker: would be a nightmare due to systemd/runit stuff
- [system requirments](./requirements/README.md)

## Install repo 

```bash
git clone git@github.com:cunialino/dotfiles.git $HOME/builds/dotfiles
cd $HOME/builds/dotfiles
nix run github:nix-community/home-manager/release-25.05 -- switch --flake .#gem
```

The only pain point I found with home-manager/nix, is the immutability of lazy-lock.json for nvim.

My workaround was to set lock path in [lazy-settings](./modules/nvim/conf/lua/core/lazy.lua). 
If repo not at that path, change it accordingly.

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
