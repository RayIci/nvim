---neotest
---@param r ValeRoles
return function(r)
  return {
    NeotestPassed = { fg = r.ok },
    NeotestFailed = { fg = r.error },
    NeotestRunning = { fg = r.warn },
    NeotestSkipped = { fg = r.info },
    NeotestUnknown = { fg = r.fg_muted },
    NeotestWatching = { fg = r.warn },
    NeotestTest = { fg = r.fg },
    NeotestNamespace = { fg = r.type },
    NeotestFile = { fg = r.fg },
    NeotestDir = { fg = r.folder },
    NeotestFocused = { bold = true, underline = true },
    NeotestAdapterName = { fg = r.keyword_control, bold = true },
    NeotestIndent = { fg = r.guide },
    NeotestExpandMarker = { fg = r.guide },
    NeotestWinSelect = { fg = r.accent, bold = true },
    NeotestMarked = { fg = r.warn, bold = true },
    NeotestTarget = { fg = r.error },
    NeotestBorder = { fg = r.border_float },
  }
end
