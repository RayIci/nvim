---todo-comments.nvim: highlight and search TODO/FIXME/HACK/NOTE comments.
---@class PluginTodoComments
local M = {}

function M.setup()
  require("todo-comments").setup({})

  local map = vim.keymap.set
  map("n", "<leader>ft", "<cmd>TodoTelescope<cr>", { desc = "Find TODOs" })
  map("n", "<leader>xt", "<cmd>Trouble todo toggle<cr>", { desc = "TODOs panel" })
  map("n", "]t", function()
    require("todo-comments").jump_next()
  end, { desc = "Next TODO" })
  map("n", "[t", function()
    require("todo-comments").jump_prev()
  end, { desc = "Previous TODO" })
end

return M
