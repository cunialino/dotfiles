-- require'npairs'.setup({ break_line_filetype = nil, check_ts = true })
--
-- _G.MUtils = {}
--
-- local cmp_autopairs = require('nvim-autopairs.completion.cmp')
-- local cmp = require('cmp')
-- cmp.event:on('confirm_done', cmp_autopairs.on_confirm_done())
-- MUtils.completion_confirm = function()
--   if vim.fn.pumvisible() ~= 0 then
--     return npairs.esc("<cr>")
--   else
--     return npairs.autopairs_cr()
--   end
-- end
--
-- remap('i', '<CR>', 'v:lua.MUtils.completion_confirm()', {expr = true, noremap = true})
local npairs = require("nvim-autopairs")
local Rule = require('nvim-autopairs.rule')

  npairs.setup({check_ts = true})

-- local ts_conds = require('nvim-autopairs.ts-conds')
--
---- press % => %% only while inside a comment or string
-- npairs.add_rules({
--  Rule("%", "%", "lua"):with_pair(ts_conds.is_ts_node({'string', 'comment'})),
--  Rule("$", "$", "lua"):with_pair(ts_conds.is_not_ts_node({'function'}))
-- })
