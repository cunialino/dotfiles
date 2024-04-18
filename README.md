# Dotfiles

My dotfiles.

I organized them so that they are usable both from a Void-Linux distribution and from wsl (using wezterm from Windows host).

## Install repo 

```bash
git clone --bare git@github.com:cunialino/dotfiles.git $HOME/builds/dotfiles
git --git-dir=$HOME/dotfiles/dotfiles/ --work-tree=$HOME checkout
```

Install requirements.

## Mold

[mold](https://github.com/rui314/mold) is a much faster linter, to always use it, link it to ~/.local/bin/ld:
```bash
sudo ln -s /usr/bin/mold ~/.local/bin/ld
```

Make also use ~/.local/bin/ld is in your PATH before /use/bin/.

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
with-env { XDG_RUNTIME_DIR:"/tmp/sway"} {sway}
```
