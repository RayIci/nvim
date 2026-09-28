---multicursor.nvim (plugins/visual-multi.lua links these to Cursor/Visual at
---setup; vale defines them directly so they survive `hi clear`)
---@param r ValeRoles
return function(r)
  return {
    MultiCursorCursor = { fg = r.bg, bg = r.cursor },
    MultiCursorVisual = { bg = r.selection },
    MultiCursorSign = { fg = r.accent },
    MultiCursorMainSign = { fg = r.accent, bold = true },
    MultiCursorMatchPreview = { bg = r.search },
    MultiCursorDisabledCursor = { fg = r.bg, bg = r.fg_muted },
    MultiCursorDisabledVisual = { bg = r.selection_inactive },
    MultiCursorDisabledSign = { fg = r.fg_muted },
  }
end
