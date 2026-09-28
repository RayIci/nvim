---telescope.nvim
---@param r ValeRoles
return function(r)
  return {
    TelescopeNormal = { fg = r.fg, bg = r.bg_float },
    TelescopeBorder = { fg = r.border_float, bg = r.bg_float },
    TelescopeTitle = { fg = r.fg_bright, bg = r.bg_float, bold = true },
    TelescopePromptNormal = { fg = r.fg, bg = r.bg_float },
    TelescopePromptBorder = { fg = r.accent, bg = r.bg_float },
    TelescopePromptTitle = { fg = r.fg_on_accent, bg = r.accent, bold = true },
    TelescopePromptPrefix = { fg = r.accent },
    TelescopePromptCounter = { fg = r.fg_muted },
    TelescopeResultsNormal = { fg = r.fg, bg = r.bg_float },
    TelescopeResultsBorder = { fg = r.border_float, bg = r.bg_float },
    TelescopeResultsTitle = { fg = r.fg_muted, bg = r.bg_float },
    TelescopePreviewNormal = { fg = r.fg, bg = r.bg_float },
    TelescopePreviewBorder = { fg = r.border_float, bg = r.bg_float },
    TelescopePreviewTitle = { fg = r.fg_muted, bg = r.bg_float },
    TelescopeSelection = { fg = r.fg_bright, bg = r.selection },
    TelescopeSelectionCaret = { fg = r.accent, bg = r.selection },
    TelescopeMultiSelection = { fg = r.keyword_control },
    TelescopeMultiIcon = { fg = r.keyword_control },
    TelescopeMatching = { fg = r.link, bold = true },
    TelescopePreviewLine = { bg = r.bg_line },
    TelescopePreviewMatch = { bg = r.search },
    TelescopeResultsDiffAdd = { fg = r.git_add },
    TelescopeResultsDiffChange = { fg = r.git_change },
    TelescopeResultsDiffDelete = { fg = r.git_delete },
    TelescopeResultsDiffUntracked = { fg = r.fg_muted },
  }
end
