local handle = io.popen("cat lua/dashboard-config/neovim.cat | lolcat")
local result = handle:read("*a")
handle:close()
print(result)
