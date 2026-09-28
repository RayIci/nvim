---flash.nvim
---@param r ValeRoles
return function(r)
  return {
    FlashBackdrop = { fg = r.fg_muted },
    FlashMatch = { fg = r.fg_bright, bg = r.search },
    FlashCurrent = { fg = r.fg_bright, bg = r.search_current },
    FlashLabel = { fg = r.bg, bg = r.error, bold = true },
    FlashPrompt = { fg = r.fg, bg = r.bg_float },
    FlashPromptIcon = { fg = r.accent, bg = r.bg_float },
    FlashCursor = { link = "Cursor" },
  }
end
