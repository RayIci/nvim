---overseer.nvim: task runner with VSCode .vscode/tasks.json support.
---With nvim-dap installed, overseer automatically runs preLaunchTask /
---postDebugTask declared in launch.json debug configurations.
---@class PluginOverseer
local M = {}

function M.setup()
  require("overseer").setup({
    task_list = { direction = "bottom", min_height = 12 },
  })

  local map = vim.keymap.set
  map("n", "<leader>ot", "<cmd>OverseerToggle<cr>", { desc = "Task list" })
  map("n", "<leader>or", "<cmd>OverseerRun<cr>", { desc = "Run task" })
  map("n", "<leader>oq", "<cmd>OverseerQuickAction<cr>", { desc = "Task quick action" })
end

return M
