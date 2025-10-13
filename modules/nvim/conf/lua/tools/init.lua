local tool_utils = {}
tool_utils.tools_table = {
  python = {
    dap = { "debugpy" },
    linters = { "mypy" },
    formatters = { "ruff_fix", "ruff_format", "ruff_organize_import" }
  },
  lua = {
    formatters = { "stylua" },
  },
  nix = {
    formatters = { "nixfmt" }
  },
  sql = {
    formatters = { "sqlfluff" },
    linters = { "sqlfluff" }
  },
  rust = {
    formatters = { rustfmt = { install_with_mason = false } },
  },
  json = {
    formatters = { "jq" },
    linters = { "jq" },
  },
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

function tool_utils.tool_by_type(type)
  local tooltype_by_ft = {}
  for ft, tools in pairs(tool_utils.tools_table) do
    tooltype_by_ft[ft] = tools[type]
  end
  return tooltype_by_ft
end

return tool_utils
