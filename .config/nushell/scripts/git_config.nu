export-env {

  let gd = $env.HOME ++ /builds/dotfiles
  let new_env = {
      GIT_DIR: $gd
      GIT_WORK_TREE: $env.HOME
  }
    load-env  $new_env 
}

export alias degc = overlay hide git_config
