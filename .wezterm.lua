local wezterm = require 'wezterm'

local config = wezterm.config_builder()

config.color_scheme = 'AdventureTime'

config.color_scheme = 'catppuccin-mocha'
config.enable_tab_bar = false

return config
