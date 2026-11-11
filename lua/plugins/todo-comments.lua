---todo-comments.nvim: highlight and search TODO/FIXME/HACK/NOTE comments.
---@class PluginTodoComments
local M = {}

---@type (string|PackSpec)[]
M.spec = {
  "folke/todo-comments.nvim",
}

function M.setup()
  require("todo-comments").setup({})

  local map = vim.keymap.set
  map("n", "<leader>ft", function()
    Snacks.picker.todo_comments()
  end, { desc = "Find TODOs" })
  map("n", "<leader>xt", "<cmd>Trouble todo toggle<cr>", { desc = "TODOs panel" })
  map("n", "]t", function()
    require("todo-comments").jump_next()
  end, { desc = "Next TODO" })
  map("n", "[t", function()
    require("todo-comments").jump_prev()
  end, { desc = "Previous TODO" })
end

return M
