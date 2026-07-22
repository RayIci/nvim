---lspsaga.nvim: selected richer LSP UIs only.
---@class PluginLspsaga
local M = {}

function M.setup()
  require("lspsaga").setup({
    symbol_in_winbar = { enable = false },
    lightbulb = { enable = false },
    implement = { enable = false },
    finder = {
      default = "ref+imp",
      methods = {
        tyd = "textDocument/typeDefinition",
      },
    },
    code_action = {
      show_server_name = true,
    },
    ui = {
      code_action = "💡",
    },
  })
end

return M
