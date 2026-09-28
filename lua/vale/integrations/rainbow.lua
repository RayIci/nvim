---rainbow-delimiters.nvim. VS Code colours bracket pairs with a 3-colour
---cycle; the plugin's default list has 7 groups, mapped here so levels 1-6
---repeat the cycle (level 7 then wraps back to level 1).
---@param r ValeRoles
return function(r)
  return {
    RainbowDelimiterRed = { fg = r.rainbow_1 },
    RainbowDelimiterYellow = { fg = r.rainbow_2 },
    RainbowDelimiterBlue = { fg = r.rainbow_3 },
    RainbowDelimiterOrange = { fg = r.rainbow_1 },
    RainbowDelimiterGreen = { fg = r.rainbow_2 },
    RainbowDelimiterViolet = { fg = r.rainbow_3 },
    RainbowDelimiterCyan = { fg = r.rainbow_1 },
  }
end
