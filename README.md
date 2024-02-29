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

## Install repo

```bash
git clone --bare https://github.com/cunialino/dotfiles.git $HOME/builds/dotfiles
git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME
git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME checkout
```

## NUSHELL

change default shell
```bash
chsh -s /usr/bin/nu
```

## Void-Linux
Session setup:
```bash
sudo usermod -aG _seatd elia
sudo ln -s /etc/sv/seatd/ /var/service
sudo sv start seatd
```

To run sway:
```bash
mkdir /tmp/sway
with-env { XDG_RUNTIME_DIR:"/tmp/swaytmp"} {sway}
```
