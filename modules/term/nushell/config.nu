alias grep = rg
alias cat = bat
alias diff = difft
alias find = fd
alias ag = overlay use git_config.nu
alias z = zellij_sessionizer.sh
alias s = tmux_sessionizer.sh


$env.config.show_banner = false

mkdir ($nu.data-dir | path join "vendor/autoload")
tv init nu | save -f ($nu.data-dir | path join "vendor/autoload/tv.nu")
