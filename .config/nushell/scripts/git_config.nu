export-env {
  let gd = $env.HOME ++ /builds/dotfiles
  let new_env = {
      GIT_DIR: $gd
      GIT_WORK_TREE: $env.HOME
  }
  if (not ("git_config" in (overlay list))) {
    load-env  $new_env 
  }
}

export alias dg = overlay hide -e [ PWD ] git_config
