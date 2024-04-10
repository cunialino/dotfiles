# Requirements

In this directory I keep track of the requirements for my dotfiles.

Unless otherwise states, the names refer to the ones found in the [xbps package manager](https://docs.voidlinux.org/xbps/index.html).

I diveded them into the following files:
- **requirements_term:** here are the ones for the terminal (tty, wsl whatever), xbps
- **requirements:** here are the ones for running my sway setup on bare metal.
- **requirements_pyenv_build:** additional deps for building python with [pyenv](https://github.com/pyenv/pyenv)
- **requirements_cargo:** rust tools I use -> these are for meant to go into `cargo install --locked <pkg>`
- **requirements_python:** pyhton packages I need -> `pip install <pkg>`
- **requirements_wsl:** same as **\_term**, but for pacman
