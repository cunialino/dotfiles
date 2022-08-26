local db = require('dashboard')
local home = os.getenv('HOME')
db.preview_command = 'cat | lolcat -F 0.3'
db.preview_file_path = home .. '/.config/nvim/lua/dashboard-config/neovim.cat'
db.preview_file_height = 16
db.preview_file_width = 26
db.session_directory = home .. '/.local/share/neovim_sessions'

db.custom_center = {
  { icon = '   ', desc = 'Latest session', action = 'SessionLoad' },
  { icon = '   ', desc = 'Find File     ', action = 'Telescope find_files' },
  { icon = '   ', desc = 'Search Text   ', action = 'Telescope live_grep' },
  { icon = '   ', desc = 'Recent Files  ', action = 'Telescope oldfiles' },
  { icon = '   ', desc = 'Config        ', action = 'edit ~/.config/nvim/init.lua' }, {
    icon = '   ',
    desc = 'Git           ',
    action = 'lua require("toggleterm.terminal").Terminal:new({cmd="lazygit", direction = "float"}):toggle()'
  }
}
db.custom_footer = { 'Do one thing, do it well - Unix philosophy' }
