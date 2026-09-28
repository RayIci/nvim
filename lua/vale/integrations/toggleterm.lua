---toggleterm.nvim (terminal colours come from vim.g.terminal_color_*)
---@param r ValeRoles
return function(r)
  return {
    ToggleTerm = { fg = r.fg, bg = r.bg_chrome },
    ToggleTermNormal = { fg = r.fg, bg = r.bg_chrome },
    ToggleTermBorder = { fg = r.border_float, bg = r.bg_chrome },
    ToggleTermNormalFloat = { fg = r.fg, bg = r.bg_float },
    ToggleTermFloatBorder = { fg = r.border_float, bg = r.bg_float },
  }
end
