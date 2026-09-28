---Standard Vim syntax groups (:h group-name). Treesitter captures link to
---most of these by default, so they are the base layer of code colour.
---@param r ValeRoles
---@return table<string, vim.api.keyset.highlight>
return function(r)
  return {
    Comment = { fg = r.comment },
    Constant = { fg = r.constant },
    String = { fg = r.string },
    Character = { fg = r.string },
    Number = { fg = r.number },
    Float = { fg = r.number },
    Boolean = { fg = r.boolean },
    Identifier = { fg = r.variable },
    Function = { fg = r.func },
    Statement = { fg = r.keyword_control },
    Conditional = { fg = r.keyword_control },
    Repeat = { fg = r.keyword_control },
    Label = { fg = r.label },
    Operator = { fg = r.operator },
    Keyword = { fg = r.keyword },
    Exception = { fg = r.keyword_control },
    PreProc = { fg = r.keyword_control },
    Include = { fg = r.keyword_control },
    Define = { fg = r.keyword },
    Macro = { fg = r.func },
    PreCondit = { fg = r.keyword_control },
    Type = { fg = r.type },
    StorageClass = { fg = r.keyword },
    Structure = { fg = r.type },
    Typedef = { fg = r.type },
    Special = { fg = r.escape },
    SpecialChar = { fg = r.escape },
    Tag = { fg = r.tag },
    Delimiter = { fg = r.punctuation },
    SpecialComment = { fg = r.comment, bold = true },
    Debug = { fg = r.warn },
    Underlined = { fg = r.link, underline = true },
    Ignore = { fg = r.fg_muted },
    Error = { fg = r.error },
    Todo = { fg = r.bg, bg = r.info, bold = true },
  }
end
