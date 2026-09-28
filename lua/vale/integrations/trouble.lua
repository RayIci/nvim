---trouble.nvim
---@param r ValeRoles
return function(r)
  return {
    TroubleNormal = { fg = r.fg, bg = r.bg_chrome },
    TroubleNormalNC = { fg = r.fg, bg = r.bg_chrome },
    TroubleText = { fg = r.fg },
    TroublePreview = { bg = r.selection_inactive },
    TroubleFilename = { fg = r.fg_bright, bold = true },
    TroubleDirectory = { fg = r.fg_muted },
    TroubleIconDirectory = { fg = r.folder },
    TroubleSource = { fg = r.fg_muted },
    TroubleCode = { fg = r.fg_muted },
    TroublePos = { fg = r.linenr },
    TroubleCount = { fg = r.fg_on_accent, bg = r.accent },
    TroubleIndent = { fg = r.guide },
    TroubleIndentFoldClosed = { fg = r.fg_muted },
    TroubleIndentFoldOpen = { fg = r.fg_muted },
  }
end
