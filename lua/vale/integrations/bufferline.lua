---bufferline.nvim (VS Code tabs: chrome strip, active tab on editor bg with
---an accent indicator). bufferline marks its derived groups `default`, so
---these win.
---@param r ValeRoles
return function(r)
  local off = { fg = r.fg_muted, bg = r.bg_chrome }
  local on = { fg = r.fg_bright, bg = r.bg, bold = true }
  local vis = { fg = r.fg, bg = r.bg_chrome }
  local g = {
    BufferLineFill = { bg = r.bg_chrome },
    BufferLineBackground = off,
    BufferLineBufferVisible = vis,
    BufferLineBufferSelected = on,
    BufferLineTab = off,
    BufferLineTabSelected = { fg = r.fg_bright, bg = r.bg },
    BufferLineTabSeparator = { fg = r.border, bg = r.bg_chrome },
    BufferLineTabSeparatorSelected = { fg = r.border, bg = r.bg },
    BufferLineTabClose = off,
    BufferLineSeparator = { fg = r.border, bg = r.bg_chrome },
    BufferLineSeparatorVisible = { fg = r.border, bg = r.bg_chrome },
    BufferLineSeparatorSelected = { fg = r.border, bg = r.bg },
    BufferLineOffsetSeparator = { fg = r.border, bg = r.bg_chrome },
    BufferLineIndicatorVisible = { fg = r.bg_chrome, bg = r.bg_chrome },
    BufferLineIndicatorSelected = { fg = r.accent, bg = r.bg },
    BufferLineCloseButton = off,
    BufferLineCloseButtonVisible = vis,
    BufferLineCloseButtonSelected = { fg = r.fg, bg = r.bg },
    BufferLineModified = { fg = r.fg_muted, bg = r.bg_chrome },
    BufferLineModifiedVisible = { fg = r.fg, bg = r.bg_chrome },
    BufferLineModifiedSelected = { fg = r.fg_bright, bg = r.bg },
    BufferLineDuplicate = { fg = r.fg_muted, bg = r.bg_chrome, italic = true },
    BufferLineDuplicateVisible = { fg = r.fg_muted, bg = r.bg_chrome, italic = true },
    BufferLineDuplicateSelected = { fg = r.fg_muted, bg = r.bg, italic = true },
    BufferLineNumbers = off,
    BufferLineNumbersVisible = vis,
    BufferLineNumbersSelected = on,
    BufferLinePick = { fg = r.error, bg = r.bg_chrome, bold = true },
    BufferLinePickVisible = { fg = r.error, bg = r.bg_chrome, bold = true },
    BufferLinePickSelected = { fg = r.error, bg = r.bg, bold = true },
    BufferLineTruncMarker = { fg = r.fg_muted, bg = r.bg_chrome },
    BufferLineGroupLabel = { fg = r.bg_chrome, bg = r.fg_muted },
    BufferLineGroupSeparator = { fg = r.fg_muted, bg = r.bg_chrome },
  }
  local diag = { Error = r.error, Warning = r.warn, Info = r.info, Hint = r.hint }
  for name, color in pairs(diag) do
    g["BufferLine" .. name] = { fg = color, bg = r.bg_chrome }
    g["BufferLine" .. name .. "Visible"] = { fg = color, bg = r.bg_chrome }
    g["BufferLine" .. name .. "Selected"] = { fg = color, bg = r.bg, bold = true }
    g["BufferLine" .. name .. "Diagnostic"] = { fg = color, bg = r.bg_chrome }
    g["BufferLine" .. name .. "DiagnosticVisible"] = { fg = color, bg = r.bg_chrome }
    g["BufferLine" .. name .. "DiagnosticSelected"] = { fg = color, bg = r.bg }
  end
  g.BufferLineDiagnostic = { fg = r.fg_muted, bg = r.bg_chrome }
  g.BufferLineDiagnosticVisible = { fg = r.fg_muted, bg = r.bg_chrome }
  g.BufferLineDiagnosticSelected = { fg = r.fg_muted, bg = r.bg }
  return g
end
