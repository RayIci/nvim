---indent-blankline.nvim (ibl): indent guides.
---@class PluginIndent
local M = {}

---@type (string|PackSpec)[]
M.spec = {
  "lukas-reineke/indent-blankline.nvim",
}

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
