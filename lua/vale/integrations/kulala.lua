---kulala.nvim (http language pack)
---@param r ValeRoles
return function(r)
  return {
    KulalaTab = { fg = r.fg_muted, bg = r.bg_chrome },
    KulalaTabSel = { fg = r.fg_bright, bg = r.bg, bold = true },
  }
end
