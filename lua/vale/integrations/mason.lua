---mason.nvim
---@param r ValeRoles
return function(r)
  return {
    MasonNormal = { fg = r.fg, bg = r.bg_float },
    MasonHeader = { fg = r.fg_on_accent, bg = r.accent, bold = true },
    MasonHeaderSecondary = { fg = r.fg_on_accent, bg = r.type, bold = true },
    MasonHighlight = { fg = r.link },
    MasonHighlightBlock = { fg = r.fg_on_accent, bg = r.accent },
    MasonHighlightBlockBold = { fg = r.fg_on_accent, bg = r.accent, bold = true },
    MasonHighlightSecondary = { fg = r.type },
    MasonHighlightBlockSecondary = { fg = r.bg, bg = r.type },
    MasonHighlightBlockBoldSecondary = { fg = r.bg, bg = r.type, bold = true },
    MasonMuted = { fg = r.fg_muted },
    MasonMutedBlock = { fg = r.fg, bg = r.bg_surface },
    MasonMutedBlockBold = { fg = r.fg_bright, bg = r.bg_surface, bold = true },
    MasonError = { fg = r.error },
    MasonWarning = { fg = r.warn },
    MasonHeading = { fg = r.fg_bright, bold = true },
    MasonLink = { fg = r.link, underline = true },
    MasonBackdrop = { bg = r.bg_chrome },
  }
end
