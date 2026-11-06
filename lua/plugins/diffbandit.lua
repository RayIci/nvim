---diffbandit.nvim: two-pane diffs that keep each side's shape and line
---numbers, with a connector gutter between them, a commit panel and a 3-way
---conflict resolver. On trial next to diffview, which keeps <leader>gd.
---@class PluginDiffbandit
local M = {}

---@type (string|PackSpec)[]
M.spec = {
  -- main until a release has close(), :DiffBanditClose and commit-message
  -- drafts (v0.3.0 has none of them); then vim.version.range("0"). The
  -- lockfile pins the exact revision either way.
  { src = "CoreyKaylor/diffbandit.nvim", version = "main" },
}

-- `-` (fugitive's toggle-stage key) instead of diffbandit's <Space>, which is
-- the leader here: a buffer-local <Space> would wait out 'timeoutlen' on every
-- press. Staging and amend share it because they live in different windows.
local toggle = "-"

function M.setup()
  require("diffbandit").setup({
    actions = { keys = { toggle_stage = toggle } },
    git = { panel = { keys = { toggle_stage = toggle, toggle_amend = toggle } } },
    folder = { keys = { toggle_expand = toggle } },
  })

  local map = vim.keymap.set
  map("n", "<leader>gxx", "<cmd>DiffBanditGit<cr>", { desc = "All changes" })
  map("n", "<leader>gxs", "<cmd>DiffBanditGit --staged<cr>", { desc = "Staged changes" })
  map("n", "<leader>gxf", "<cmd>DiffBanditGitCurrent<cr>", { desc = "Current file" })
  map("n", "<leader>gxc", "<cmd>DiffBanditCommitPanel<cr>", { desc = "Commit panel" })
  map("n", "<leader>gxb", function()
    require("diffbandit").git_compare_branches({})
  end, { desc = "Compare branches" })
  map("n", "<leader>gxl", "<cmd>DiffBanditGitLog<cr>", { desc = "Commit log" })
  map("n", "<leader>gxm", "<cmd>DiffBanditGitMenu<cr>", { desc = "Menu" })
  map("n", "<leader>gxq", "<cmd>DiffBanditClose<cr>", { desc = "Close view" })
end

return M
