---nvim-window-picker
---@param r ValeRoles
return function(r)
  return {
    WindowPickerStatusLine = { fg = r.fg_on_accent, bg = r.accent, bold = true },
    WindowPickerStatusLineNC = { fg = r.fg_on_accent, bg = r.accent, bold = true },
    WindowPickerWinBar = { fg = r.fg_on_accent, bg = r.accent, bold = true },
    WindowPickerWinBarNC = { fg = r.fg_on_accent, bg = r.accent, bold = true },
  }
end
