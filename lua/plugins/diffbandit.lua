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

function M.setup()
  require("diffbandit").setup()
end

return M
