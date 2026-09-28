---blink.cmp (VS Code suggest widget: float bg, blue match, kind icons in
---their syntax colours)
---@param r ValeRoles
return function(r)
  local g = {
    BlinkCmpMenu = { fg = r.fg, bg = r.bg_float },
    BlinkCmpMenuBorder = { fg = r.border_float, bg = r.bg_float },
    BlinkCmpMenuSelection = { bg = r.selection },
    BlinkCmpScrollBarThumb = { bg = r.guide },
    BlinkCmpScrollBarGutter = { bg = r.bg_float },
    BlinkCmpLabel = { fg = r.fg },
    BlinkCmpLabelDeprecated = { fg = r.fg_muted, strikethrough = true },
    BlinkCmpLabelMatch = { fg = r.link, bold = true },
    BlinkCmpLabelDetail = { fg = r.fg_muted },
    BlinkCmpLabelDescription = { fg = r.fg_muted },
    BlinkCmpSource = { fg = r.fg_muted },
    BlinkCmpGhostText = { fg = r.ghost },
    BlinkCmpDoc = { fg = r.fg, bg = r.bg_float },
    BlinkCmpDocBorder = { fg = r.border_float, bg = r.bg_float },
    BlinkCmpDocSeparator = { fg = r.border_float, bg = r.bg_float },
    BlinkCmpDocCursorLine = { bg = r.bg_line },
    BlinkCmpSignatureHelp = { fg = r.fg, bg = r.bg_float },
    BlinkCmpSignatureHelpBorder = { fg = r.border_float, bg = r.bg_float },
    BlinkCmpSignatureHelpActiveParameter = { fg = r.link, bold = true },
    BlinkCmpKind = { fg = r.fg_muted },
  }
  local kinds = {
    Text = r.fg,
    Method = r.keyword_control,
    Function = r.keyword_control,
    Constructor = r.keyword_control,
    Field = r.link,
    Variable = r.link,
    Class = r.lightbulb,
    Interface = r.link,
    Module = r.fg,
    Property = r.fg,
    Unit = r.fg,
    Value = r.fg,
    Enum = r.lightbulb,
    Keyword = r.fg,
    Snippet = r.fg,
    Color = r.fg,
    File = r.fg,
    Reference = r.fg,
    Folder = r.fg,
    EnumMember = r.link,
    Constant = r.fg,
    Struct = r.fg,
    Event = r.lightbulb,
    Operator = r.fg,
    TypeParameter = r.fg,
    Copilot = r.fg_muted,
  }
  -- Kind colours follow VS Code's symbolIcon.* defaults: methods purple,
  -- fields/variables blue, classes/enums/events orange-yellow, rest plain.
  for kind, color in pairs(kinds) do
    g["BlinkCmpKind" .. kind] = { fg = color }
  end
  return g
end
