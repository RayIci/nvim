---git-conflict.nvim. The plugin derives its region colours from DiffAdd /
---DiffText / DiffChange on ColorScheme; these pin the vale versions.
---@param r ValeRoles
return function(r)
  return {
    GitConflictCurrent = { bg = r.diff_add },
    GitConflictCurrentLabel = { fg = r.fg_bright, bg = r.diff_add_text, bold = true },
    GitConflictIncoming = { bg = r.diff_change },
    GitConflictIncomingLabel = { fg = r.fg_bright, bg = r.diff_text, bold = true },
    GitConflictAncestor = { bg = r.bg_surface },
    GitConflictAncestorLabel = { fg = r.fg_bright, bg = r.border_float, bold = true },
  }
end
