---trouble.nvim: structured diagnostics / quickfix / references panels.
---@class PluginTrouble
local M = {}

function M.setup()
  require("trouble").setup({})

  local map = vim.keymap.set
  map("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", { desc = "Project diagnostics" })
  map("n", "<leader>xb", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", { desc = "Buffer diagnostics" })
  map("n", "<leader>xq", "<cmd>Trouble qflist toggle<cr>", { desc = "Quickfix list" })
  map("n", "<leader>xl", "<cmd>Trouble loclist toggle<cr>", { desc = "Location list" })
  map("n", "<leader>xs", "<cmd>Trouble symbols toggle<cr>", { desc = "Symbols outline" })
end

return M
