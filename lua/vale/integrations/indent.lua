---indent-blankline.nvim
---@param r ValeRoles
return function(r)
  return {
    IblIndent = { fg = r.guide, nocombine = true },
    IblWhitespace = { fg = r.guide, nocombine = true },
    IblScope = { fg = r.guide_active, nocombine = true },
  }
end
