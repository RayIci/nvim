---multicursor.nvim: pure-Lua multi-cursor editing (replaces vim-visual-multi).
---Handles undo/redo correctly and integrates with Neovim's visual/select modes.
---
---Keys:
---  <C-n>        (n/v) add cursor on next match of the word under cursor
---  <C-p>        (n/v) add cursor on previous match
---  q            (n/v) skip current match, jump to next   [while cursors exist]
---  <C-Up>/<C-Down> (n/v) add a cursor on the line above/below
---  <C-Left>/<C-Right> (n/v) rotate the main cursor
---  <leader>ma   (n/v) add cursors to all matches in the buffer
---  <leader>ms   (v)   split visual selection into per-line cursors
---  <leader>mS   (v)   add cursors for each match inside the selection
---  <leader>mi   (v)   insert at each visual line (like block-mode I)
---  <leader>mA   (v)   append at each visual line (like block-mode A)
---  <leader>mx   (n)   delete the current cursor (keep the rest)
---  <Esc>        (n)   clear all cursors (or re-enable if disabled)
---@class PluginVisualMulti
local M = {}

function M.setup()
  local mc = require("multicursor-nvim")
  mc.setup()

  local set = vim.keymap.set

  -- Add cursors matching the word under cursor (forward and backward).
  set({ "n", "v" }, "<C-n>", function()
    mc.matchAddCursor(1)
  end, { desc = "Multicursor: add next match" })

  set({ "n", "v" }, "<C-p>", function()
    mc.matchAddCursor(-1)
  end, { desc = "Multicursor: add prev match" })

  -- Keymaps that only exist while a multi-cursor session is active. These are
  -- buffer-local, so they take precedence over global mappings during a session
  -- (notably the global <Esc> -> nohlsearch in config.keymaps, which is loaded
  -- after plugins and would otherwise swallow Esc here) and vanish afterwards,
  -- leaving q and <Esc> their normal meanings.
  mc.addKeymapLayer(function(layerSet)
    layerSet({ "n", "v" }, "q", function()
      if mc.cursorsEnabled() and mc.hasCursors() then
        mc.matchSkipCursor(1)
      end
    end, { desc = "Multicursor: skip to next match" })

    -- <Esc>: exit multicursor mode (or re-enable frozen cursors first).
    layerSet("n", "<Esc>", function()
      if not mc.cursorsEnabled() then
        mc.enableCursors()
      else
        mc.clearCursors()
      end
    end, { desc = "Multicursor: clear all cursors" })
  end)

  -- Add cursors on the lines above/below.
  set({ "n", "v" }, "<C-Up>", function()
    mc.lineAddCursor(-1)
  end, { desc = "Multicursor: add cursor above" })
  set({ "n", "v" }, "<C-Down>", function()
    mc.lineAddCursor(1)
  end, { desc = "Multicursor: add cursor below" })

  -- Rotate which cursor is the "main" cursor.
  set({ "n", "v" }, "<C-Left>", function()
    if mc.cursorsEnabled() and mc.hasCursors() then
      mc.prevCursor()
    end
  end, { desc = "Multicursor: previous cursor" })

  set({ "n", "v" }, "<C-Right>", function()
    if mc.cursorsEnabled() and mc.hasCursors() then
      mc.nextCursor()
    end
  end, { desc = "Multicursor: next cursor" })

  -- Match all occurrences in the buffer.
  set({ "n", "v" }, "<leader>ma", mc.matchAllAddCursors, { desc = "Multicursor: add all matches" })

  -- Visual-selection helpers.
  set("v", "<leader>ms", mc.splitCursors, { desc = "Multicursor: split selection into lines" })
  set("v", "<leader>mS", mc.matchCursors, { desc = "Multicursor: cursors for matches in selection" })
  set("v", "<leader>mi", mc.insertVisual, { desc = "Multicursor: insert at each visual line" })
  set("v", "<leader>mA", mc.appendVisual, { desc = "Multicursor: append at each visual line" })

  -- Delete only the current cursor (keep the others active).
  set("n", "<leader>mx", mc.deleteCursor, { desc = "Multicursor: delete current cursor" })

  -- Note: <Esc> to exit is defined inside the keymap layer above (buffer-local),
  -- so it wins over the global <Esc> -> nohlsearch mapping during a session.

  -- Highlight groups for the multi-cursor state.
  vim.api.nvim_set_hl(0, "MultiCursorCursor", { link = "Cursor" })
  vim.api.nvim_set_hl(0, "MultiCursorVisual", { link = "Visual" })
  vim.api.nvim_set_hl(0, "MultiCursorSign", { link = "SignColumn" })
  vim.api.nvim_set_hl(0, "MultiCursorDisabledCursor", { link = "Visual" })
  vim.api.nvim_set_hl(0, "MultiCursorDisabledVisual", { link = "Visual" })
  vim.api.nvim_set_hl(0, "MultiCursorDisabledSign", { link = "SignColumn" })
end

return M
