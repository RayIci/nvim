---which-key.nvim
---@param r ValeRoles
return function(r)
  return {
    WhichKey = { fg = r.keyword },
    WhichKeyGroup = { fg = r.keyword_control },
    WhichKeyDesc = { fg = r.fg },
    WhichKeySeparator = { fg = r.fg_muted },
    WhichKeyValue = { fg = r.fg_muted },
    WhichKeyIcon = { fg = r.accent },
    WhichKeyNormal = { fg = r.fg, bg = r.bg_float },
    WhichKeyBorder = { fg = r.border_float, bg = r.bg_float },
    WhichKeyTitle = { fg = r.fg_bright, bg = r.bg_float, bold = true },
  }
end
