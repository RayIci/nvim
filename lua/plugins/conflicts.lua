---Guided merge-conflict resolution (lua/config/conflicts/): sides named by
---role, YOURS and INCOMING, never git's ours/theirs (which swap in a rebase);
---inline marks and keys in conflicted files, the resolve view with a live
---result preview, the conflict center, next-step commands and a statusline
---widget. This module wires the keys and the triggers; nothing runs while no
---merge, rebase, cherry-pick, revert or stash conflict is in progress.
---@class PluginConflicts
local M = {}

---@type (string|PackSpec)[]
M.spec = {} -- no plugin: the 3-way view is diffview's (plugins/diffview.lua)

function M.setup()
  local state = require("config.conflicts.state")
  local inline = require("config.conflicts.inline")
  local center = require("config.conflicts.center")

  inline.set_highlights()
  local group = vim.api.nvim_create_augroup("plugins.conflicts", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = inline.set_highlights })

  state.on_change(function()
    inline.sync()
    pcall(function()
      require("lualine").refresh()
    end)
  end)

  -- Detection: operation-state files only (no git process unless one exists).
  vim.api.nvim_create_autocmd({ "VimEnter", "FocusGained", "DirChanged", "TermLeave" }, {
    group = group,
    callback = function()
      state.refresh()
    end,
  })
  -- Conflicted files get their marks and keys when opened.
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufEnter" }, {
    group = group,
    callback = function(ev)
      if state.current then
        inline.attach(ev.buf)
      end
    end,
  })
  if vim.v.vim_did_enter == 1 then
    state.refresh()
  end

  require("plugins.lualine").register({ render = state.status })

  local map = vim.keymap.set
  map("n", "<leader>gCC", center.open, { desc = "Conflict center" })
  map("n", "<leader>gCr", function()
    require("config.conflicts.resolve").open()
  end, { desc = "Resolve view (preview, pick lines)" })
  map("n", "<leader>gCm", center.three_way, { desc = "3-way merge view" })
  map("n", "<leader>gCa", function()
    center.stage()
  end, { desc = "Stage this file (when resolved)" })
  map("n", "<leader>gCc", center.continue, { desc = "Continue the merge/rebase/…" })
  map("n", "<leader>gCA", center.abort, { desc = "Abort the merge/rebase/…" })
  map("n", "<leader>gC?", center.explain, { desc = "Explain which side is which" })
end

return M
