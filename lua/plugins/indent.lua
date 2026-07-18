---indent-blankline.nvim (ibl): indent guides.
---@class PluginIndent
local M = {}

function M.setup()
  require("ibl").setup({
    indent = { char = "│" },
    scope = { show_start = false, show_end = false },
    exclude = {
      filetypes = { "help", "dashboard", "neo-tree", "Trouble", "lazy", "mason" },
    },
  })
end

return M
