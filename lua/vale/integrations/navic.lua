---nvim-navic + barbecue.nvim (winbar breadcrumbs). barbecue's default theme
---derives its groups from Normal/Function/Type/… on ColorScheme, so it
---follows vale without a theme file; the navic groups cover navic directly.
---@param r ValeRoles
return function(r)
  local kinds = {
    File = r.fg,
    Module = r.namespace,
    Namespace = r.namespace,
    Package = r.namespace,
    Class = r.type,
    Method = r.func,
    Property = r.property,
    Field = r.property,
    Constructor = r.type,
    Enum = r.type,
    Interface = r.type,
    Function = r.func,
    Variable = r.variable,
    Constant = r.constant,
    String = r.string,
    Number = r.number,
    Boolean = r.boolean,
    Array = r.type,
    Object = r.type,
    Key = r.property,
    Null = r.boolean,
    EnumMember = r.constant,
    Struct = r.type,
    Event = r.type,
    Operator = r.operator,
    TypeParameter = r.type,
  }
  local g = {
    NavicText = { fg = r.fg_muted },
    NavicSeparator = { fg = r.fg_muted },
  }
  for kind, color in pairs(kinds) do
    g["NavicIcons" .. kind] = { fg = color }
  end
  return g
end
