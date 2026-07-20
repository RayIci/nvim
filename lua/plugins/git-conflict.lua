---git-conflict.nvim: highlight merge conflicts and resolve them by keymap.
---@class PluginGitConflict
local M = {}

function M.setup()
  require("git-conflict").setup({
    default_mappings = {
      ours = "<leader>gCo",
      theirs = "<leader>gCt",
      none = "<leader>gC0",
      both = "<leader>gCb",
      next = "<leader>gCn",
      prev = "<leader>gCp",
    },
  })

  local map = vim.keymap.set
  map("n", "<leader>gCQ", "<cmd>GitConflictListQf<cr>", { desc = "List conflicts in quickfix" })
  map("n", "<leader>gCq", function()
    vim.cmd("GitConflictListQf")
    vim.cmd("cclose")
    vim.cmd("Trouble quickfix")
  end, { desc = "List conflicts in Trouble" })
end

return M
