export-env {
  let virtual_env = ([$env.PWD .venv] | path join)
  let bin = 'bin'

  let venv_path = ([$virtual_env $bin] | path join)
  let new_path = ($env | get PATH | prepend $venv_path)

  print $env.PWD

  if (not ("venv_activate" in ...(overlay list))) and (([$env.PWD ".venv/bin/python"] | path join) | path exists) {
    let new_env = {
        PATH         : $new_path
        VIRTUAL_ENV        : $virtual_env
    }

    # Environment variables that will be loaded as the virtual env
    load-env $new_env
  }
}

export alias deactivate = overlay hide venv_activate --keep-env [ PWD ]
