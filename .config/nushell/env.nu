# Nushell Environment Config File
#
# version = "0.88.1"

# Specifies how environment variables are:
# - converted from a string to a value on Nushell startup (from_string)
# - converted from a value back to a string when running external commands (to_string)
# Note: The conversions happen *after* config.nu is loaded
$env.ENV_CONVERSIONS = {
    "PATH": {
        from_string: { |s| $s | split row (char esep) | path expand --no-symlink }
        to_string: { |v| $v | path expand --no-symlink | str join (char esep) }
    }
    "Path": {
        from_string: { |s| $s | split row (char esep) | path expand --no-symlink }
        to_string: { |v| $v | path expand --no-symlink | str join (char esep) }
    }
}

# Directories to search for scripts when calling source or use
# The default for this is $nu.default-config-dir/scripts
$env.NU_LIB_DIRS = [
    ($nu.default-config-dir | path join 'scripts') # add <nushell-config-dir>/scripts
]

# Directories to search for plugin binaries when calling register
# The default for this is $nu.default-config-dir/plugins
$env.NU_PLUGIN_DIRS = [
    ($nu.default-config-dir | path join 'plugins') # add <nushell-config-dir>/plugins
]



$env.PYENV_ROOT = ([$env.HOME, builds/pyenv] | path join)

$env.PATH = ($env.PATH | split row (char esep) | prepend ([$env.PYENV_ROOT, bin] | path join))

$env.PATH = ($env.PATH | split row (char esep) | prepend ([$env.PYENV_ROOT, shims] | path join))

$env.PATH = ($env.PATH | split row (char esep) | prepend ([$env.HOME, .cargo/bin] | path join ))

$env.PATH = ($env.PATH | split row (char esep) | prepend ~/.local/bin/ | prepend /opt/texlive/2024/bin/x86_64-linux/)

$env.EDITOR = "nvim"

$env.ZK_NOTEBOOK_DIR = ($env.HOME | path join "builds/Ohara/")
