alias grep = rg
alias cat = bat
alias diff = delta
alias find = fd
alias ag = overlay use git_config.nu
alias z = zellij_sessionizer.sh

$env.config.show_banner = false

source carapace.nu

mkdir ($nu.data-dir | path join "vendor/autoload")
tv init nu | save -f ($nu.data-dir | path join "vendor/autoload/tv.nu")
