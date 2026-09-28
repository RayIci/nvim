---nvim-lightbulb
---@param r ValeRoles
return function(r)
  return {
    LightBulbSign = { fg = r.lightbulb },
    LightBulbVirtualText = { fg = r.lightbulb },
    LightBulbFloatWin = { fg = r.lightbulb, bg = r.bg_float },
    LightBulbNumber = { fg = r.lightbulb },
    LightBulbLine = { bg = r.bg_line },
  }
end
