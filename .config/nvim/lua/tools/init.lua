local tool_utils = {}
tool_utils.tools_table = {
 python = {
    formatters = { "ruff", "typos", "codespell" },
    dap = { "debugpy" },
    lsp = { "ruff_lsp" }
  },
  lua = {
    lsp = { "lua_ls"},
    formatters = { "stylua" }
  },
  yaml = {
    linters = {"actionlint"}
  },
  markdown = {
    linters = {"proselint"}
  }
}

function tool_utils.parse_table(tool_type_filter)
  local merged_tools = {}
  for _, ft in pairs(tool_utils.tools_table) do
    for tool_type, tools in pairs(ft) do
      if tool_type_filter == nil or tool_type == tool_type_filter then
      for _, tool in ipairs(tools) do
        if not vim.tbl_contains(merged_tools, tool) then
          table.insert(merged_tools, tool)
        end
      end
      end
    end
  end
  return merged_tools
end

return tool_utils
