--local util = vim.lsp.util
--local log = require("vim.lsp.log")
--local function location_handler(_, method, result)
--	local _ = log.info() and log.info("ciao")
--	if result == nil or vim.tbl_isempty(result) then
--		local _ = log.info() and log.info(method, "No location found")
--		return nil
--	end
--
--	if vim.tbl_islist(result) then
--		util.jump_to_location(result[1])
--
--		if #result > 1 then
--			util.set_qflist(util.locations_to_items(result))
--		end
--	else
--		util.jump_to_location(result)
--	end
--end

icons = {
  lsp_signs = { Error = "", Warning = "", Hint = "", Information = "" },
  separators = { Left = "", Right = "" },
}
ide_settings = {
  staline_theme = "normal",
  indent = { rainbow = false },
  language_servers = {
    sumneko_lua = {
      config = function(opts)
        opts = vim.tbl_deep_extend("force", {
          settings = {
            Lua = {
              runtime = { version = "LuaJIT", path = vim.split(package.path, ";") },
              diagnostics = { globals = { "vim" } },
              workspace = {
                library = vim.api.nvim_get_runtime_file("", true),
                checkThirdParty = false,
                preloadFileSize = 10000,
              },
              telemetry = { enable = false },
            },
          },
        }, opts)
        return opts
      end,
    },
    jsonls = {
      config = function(opts)
        opts = vim.tbl_deep_extend("force", {
          settings = { json = { schemas = require("schemastore").json.schemas() } },
        }, opts)
        return opts
      end,
    },
    -- tsserver = {
    --   config = function(opts)
    --     opts = vim.tbl_deep_extend("force",
    --       { handlers = { ["textDocument/definition"] = location_handler } },
    --       opts)
    --     return opts
    --   end
    -- }
  },
}

UtilityFunctions = {
  saveAndExit = function()
    vim.cmd("SessionSave")
    vim.cmd("q")
  end,
  syncPlugins = function()
    vim.cmd("PackerSnapshot backup")
    vim.cmd("PackerSync")
  end,
  preview = function()
    local filetype = vim.bo.filetype
    if filetype == "tex" then
      vim.cmd("LatexPreviewToggle")
    elseif filetype == "markdown" then
      vim.cmd("MarkdownPreviewToggle")
    end
  end,
}
