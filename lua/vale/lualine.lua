---lualine theme for vale. VS Code's status bar is one flat chrome strip;
---the mode badge (section a) adds the only colour, keyed per mode.
---@param variant ValeVariant
---@return table
return function(variant)
  local vale = require("vale")
  local cur = vale.current
  local r = (cur and cur.variant == variant) and cur.r or select(3, vale.build(variant))

  local function mode(color)
    return {
      a = { fg = r.fg_on_accent, bg = color, gui = "bold" },
      b = { fg = r.fg, bg = r.bg_surface },
      c = { fg = r.fg, bg = r.bg_chrome },
    }
  end

  return {
    normal = mode(r.accent),
    insert = mode(r.git_add),
    visual = mode(r.keyword_control),
    replace = mode(r.error),
    command = mode(r.warn),
    terminal = mode(r.type),
    inactive = {
      a = { fg = r.fg_muted, bg = r.bg_chrome },
      b = { fg = r.fg_muted, bg = r.bg_chrome },
      c = { fg = r.fg_muted, bg = r.bg_chrome },
    },
  }
end
