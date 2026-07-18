---flash.nvim: jump-anywhere motions.
---@class PluginFlash
local M = {}

function M.setup()
  require("flash").setup({})

  local map = vim.keymap.set
  map({ "n", "x", "o" }, "s", function()
    require("flash").jump()
  end, { desc = "Flash jump" })
  map({ "n", "x", "o" }, "S", function()
    require("flash").treesitter()
  end, { desc = "Flash treesitter select" })
  map({ "o", "x" }, "R", function()
    require("flash").treesitter_search()
  end, { desc = "Flash treesitter search" })
end

return M
