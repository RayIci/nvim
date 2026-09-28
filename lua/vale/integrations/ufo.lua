---nvim-ufo
---@param r ValeRoles
return function(r)
  return {
    UfoFoldedBg = { bg = r.bg_line },
    UfoFoldedFg = { fg = r.fg },
    UfoFoldedEllipsis = { fg = r.fg_muted, bg = r.bg_surface },
    UfoCursorFoldedLine = { bg = r.bg_surface },
    UfoPreviewCursorLine = { bg = r.bg_line },
    UfoPreviewWinBar = { fg = r.fg_muted, bg = r.bg_float },
    UfoPreviewSbar = { bg = r.bg_float },
    UfoPreviewThumb = { bg = r.guide },
  }
end
