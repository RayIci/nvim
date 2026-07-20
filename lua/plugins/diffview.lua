---diffview.nvim: side-by-side diffs and git history browsing.
---@class PluginDiffview
local M = {}

function M.setup()
  require("diffview").setup()

  local map = vim.keymap.set
  map("n", "<leader>gdd", "<cmd>DiffviewOpen<cr>", { desc = "Open" })
  map("n", "<leader>gdo", "<cmd>DiffviewOpen<cr>", { desc = "Open" })
  map("n", "<leader>gdc", "<cmd>DiffviewClose<cr>", { desc = "Close" })
  map("n", "<leader>gdr", "<cmd>DiffviewRefresh<cr>", { desc = "Refresh" })
  map("n", "<leader>gdt", "<cmd>DiffviewToggleFiles<cr>", { desc = "Toggle file panel" })
  map("n", "<leader>gdf", "<cmd>DiffviewFileHistory %<cr>", { desc = "File history" })
  map("n", "<leader>gdp", "<cmd>DiffviewFileHistory<cr>", { desc = "File history (project)" })
end

return M
