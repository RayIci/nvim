---snacks.nvim (notifier is the enabled module; base window groups included)
---@param r ValeRoles
return function(r)
  local g = {
    SnacksNormal = { fg = r.fg, bg = r.bg_float },
    SnacksNormalNC = { fg = r.fg, bg = r.bg_float },
    SnacksWinBar = { fg = r.fg_bright, bg = r.bg_float, bold = true },
    SnacksBackdrop = { bg = r.bg_chrome },
    SnacksTitle = { fg = r.fg_bright, bold = true },
    SnacksFooter = { fg = r.fg_muted },
    SnacksFooterKey = { fg = r.keyword },
    SnacksFooterDesc = { fg = r.fg_muted },
    SnacksDim = { fg = r.fg_muted },
    SnacksNotifierHistory = { fg = r.fg, bg = r.bg_float },
    SnacksNotifierHistoryTitle = { fg = r.fg_bright, bold = true },
    SnacksNotifierHistoryDateTime = { fg = r.fg_muted },
    SnacksNotifierMinimal = { fg = r.fg, bg = r.bg_float },
    SnacksIndent = { fg = r.guide },
    SnacksIndentScope = { fg = r.guide_active },
    SnacksInputNormal = { fg = r.fg, bg = r.bg_float },
    SnacksInputBorder = { fg = r.accent, bg = r.bg_float },
    SnacksInputTitle = { fg = r.fg_bright, bg = r.bg_float, bold = true },
    SnacksInputIcon = { fg = r.accent },
    SnacksPickerMatch = { fg = r.link, bold = true },
    SnacksPickerDir = { fg = r.fg_muted },
    SnacksPickerFile = { fg = r.fg },
  }
  local levels = { Info = r.info, Warn = r.warn, Error = r.error, Debug = r.fg_muted, Trace = r.fg_muted }
  for level, color in pairs(levels) do
    g["SnacksNotifier" .. level] = { fg = r.fg, bg = r.bg_float }
    g["SnacksNotifierIcon" .. level] = { fg = color, bg = r.bg_float }
    g["SnacksNotifierTitle" .. level] = { fg = color, bg = r.bg_float, bold = true }
    g["SnacksNotifierBorder" .. level] = { fg = color, bg = r.bg_float }
    g["SnacksNotifierFooter" .. level] = { fg = r.fg_muted, bg = r.bg_float }
  end
  return g
end
