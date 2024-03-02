const plugins_dir = ~/.local/share/zellij/plugins/

mkdir $plugins_dir

cd $plugins_dir

let plugins = [
  [name url];
  [zjstatus https://github.com/dj95/zjstatus/releases/download/v0.11.2/zjstatus.wasm]
  [multitask https://github.com/imsnif/multitask/releases/download/0.38.2v2/multitask.wasm]
]

$plugins | each { |it|
  let name = ($it | get name)
  let url = ($it | get url)
  if not ((ls -s $plugins_dir | where name == ($name ++ .wasm) | length) > 0) {

    curl -L $url | save ($name ++ .wasm)
  }
}

cd -
