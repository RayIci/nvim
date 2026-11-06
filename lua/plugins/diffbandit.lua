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

---Close every diffbandit view (diff, merge, folder, standalone commit panel)
---in every tab. A no-op when diffbandit was never loaded, so it is safe on any
---switch or exit. Closing a commit panel keeps its message as a draft and
---deletes its buffers, so no modified commit buffer is left for a later
---save-all to write (which would commit).
function M.close_all()
  if not package.loaded.diffbandit then
    return
  end
  local diffbandit = require("diffbandit")
  local start = vim.api.nvim_get_current_tabpage()
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    if vim.api.nvim_tabpage_is_valid(tab) and diffbandit.is_running({ tab = tab, panel = true }) then
      vim.api.nvim_set_current_tabpage(tab)
      diffbandit.close()
    end
  end
  if vim.api.nvim_tabpage_is_valid(start) then
    vim.api.nvim_set_current_tabpage(start)
  end
end

local options = {
  actions = { keys = { toggle_stage = toggle } },
  git = { panel = { keys = { toggle_stage = toggle, toggle_amend = toggle } } },
  folder = { keys = { toggle_expand = toggle } },
}

---Configure diffbandit the first time anything requires it (its commands, the
---keymaps below), instead of at startup: requiring it loads ~50 modules
---(about 10 ms), which its own plugin/ file is written to avoid.
local function configure_on_first_require()
  package.preload.diffbandit = function(name)
    package.preload.diffbandit = nil
    local path = vim.api.nvim_get_runtime_file("lua/diffbandit/init.lua", false)[1]
    local diffbandit = assert(loadfile(assert(path, "diffbandit.nvim is not on 'runtimepath'")))(name)
    package.loaded[name] = diffbandit
    diffbandit.setup(options)
    return diffbandit
  end
end

function M.setup()
  if package.loaded.diffbandit then
    package.loaded.diffbandit.setup(options)
  else
    configure_on_first_require()
  end

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
