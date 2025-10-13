# Dotfiles

My dotfiles. I just switched them to [home-manager](https://nix-community.github.io/home-manager/).

I also made the switch to [NixOS](https://nixos.org)

## Nixos 

I just switched my first machine to nix-os, now the flake manages two things:

- home-manager: I want to keep this for flexibility, so that I can have my dotfiles on non-nixos machines
- nixos: a full on system, which also relies on home-manager for dotfiles.

## Install repo 

To use home-manager run the following:

```bash
git clone git@github.com:cunialino/dotfiles.git $HOME/builds/dotfiles
cd $HOME/builds/dotfiles
nix run github:nix-community/home-manager/release-25.05 -- switch --flake .#gem
```

To fresh install nixos, follow the [wiki](https://nixos.wiki/wiki/NixOS_Installation_Guide) 
and replace the nix-install command with:

```bash
nixos-install --flake github:cunialino/dotfiles#<system_name>
```

`<system_name>` must be defined in the flake.nix `host_os` attrset.

## TODO 

There are a couple of things I would still like to improve:

- [ ] make nixgl optional, so that nixos doesn't import that and I only have it on home-manager only gui setups
- [x] reduce code repetitions for home-manager between hm-only and nixos.
- [x] abstract common system level stuff for nixos, there are some things I always need and that will be in common between most systems.
- [ ] study a way to make debugpy work when adding it to extraPackages
- [ ] what i did for nvim-treesitter feels really wrong...
- [x] make use of lib.mkIf instead of imports, this way it's much easier to modularize stuff

### Workflow

Some improvments strictly related to terminal workflow:

- [ ] make use of [nvim remote](https://neovim.io/doc/user/remote.html) to use terminal yazi to open files
- [ ] remove vim-slime and implement lua logic myself with tmux send
- [ ] switch to fish shell, I'm tired of incompatibilities of nushell, I don't even use nushell features so much
