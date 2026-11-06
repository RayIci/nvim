---git-worktree: managed git worktrees where switching replaces the whole
---workspace (RayIci/git-worktree.nvim). This module wires the plugin into
---this configuration: the integrations it should use, this configuration's
---workspace persistence as a participant, and the keymaps.
---@class PluginGitWorktree
local M = {}

---@type (string|PackSpec)[]
M.spec = {
  "RayIci/git-worktree.nvim",
}

function M.setup()
  local worktree = require("git-worktree")
  worktree.setup({
    integrations = { "auto_session", "neogit", "dap", "scope", "bufferline", "neotree" },
  })
  -- Buffers, pins, breakpoints, explorer and scope state (config/workspace/).
  worktree.register(require("config.workspace").participant)

  vim.api.nvim_create_autocmd("User", {
    group = vim.api.nvim_create_augroup("config.git-worktree", { clear = true }),
    pattern = "GitWorktreeSwitched",
    callback = function()
      require("config.workspace").touch()
    end,
  })

  local map = vim.keymap.set
  map("n", "<leader>gww", worktree.switch, { desc = "Switch worktree workspace" })
  map("n", "<leader>gwc", worktree.create, { desc = "Create worktree workspace" })
  map("n", "<leader>gwd", worktree.delete, { desc = "Delete inactive worktree" })
end

return M
