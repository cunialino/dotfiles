# Dotfiles

Shell related dotfiles.

Requirements:

- [exa](https://the.exa.website/): modern version of ls
- [bat](https://github.com/sharkdp/bat): modern version of cat
- [bat-extras](https://github.com/eth-p/bat-extras): nice stuff
- [ripgrep](https://blog.burntsushi.net/ripgrep/): modern version of grep
- [fd](https://github.com/sharkdp/fd): modern version of find
- [delta](https://github.com/dandavison/delta): modern version of diff
- [fzf](https://github.com/junegunn/fzf)
- [nvim](https://neovim.io/)
  - [pynvim](https://github.com/neovim/pynvim)
- [nord-dircolors](https://github.com/arcticicestudio/nord-dircolors): link this to ~/.dir_colors

## ZSH

- install zsh

change default shell
```bash
chsh -s /usr/bin/zsh
```

clone ohmyzh
```bash
git clone https://github.com/ohmyzsh.git $HOME/builds/ohmyzsh
```

clone powerlevel10k
```bash
git clone https://github.com/romkatv/powerlevel10k.git builds/ohmyzsh/custom/themes/powerlevel10k
```

## I3 and Lemonbar

- install i3 (i3-gaps has been merged)
- install lemonbar-xft-git
  - install jq, acpi and alsa-utils
- install devilspie

## Neovim

it works out of the box, but here we define the pyhton configuration.
