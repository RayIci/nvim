---Treesitter captures (:h treesitter-highlight-groups, Neovim 0.12).
---Mapped the way VS Code's TextMate scopes colour the same constructs.
---@param r ValeRoles
---@return table<string, vim.api.keyset.highlight>
return function(r)
  return {
    ["@variable"] = { fg = r.variable },
    ["@variable.builtin"] = { fg = r.builtin },
    ["@variable.parameter"] = { fg = r.parameter },
    ["@variable.parameter.builtin"] = { fg = r.builtin },
    ["@variable.member"] = { fg = r.property },

    ["@constant"] = { fg = r.constant },
    ["@constant.builtin"] = { fg = r.boolean },
    ["@constant.macro"] = { fg = r.constant },

    ["@module"] = { fg = r.namespace },
    ["@module.builtin"] = { fg = r.namespace },
    ["@label"] = { fg = r.label },

    ["@string"] = { fg = r.string },
    ["@string.documentation"] = { fg = r.string },
    ["@string.regexp"] = { fg = r.regex },
    ["@string.escape"] = { fg = r.escape },
    ["@string.special"] = { fg = r.escape },
    ["@string.special.symbol"] = { fg = r.constant },
    ["@string.special.path"] = { fg = r.string },
    ["@string.special.url"] = { fg = r.link, underline = true },

    ["@character"] = { fg = r.string },
    ["@character.special"] = { fg = r.escape },

    ["@boolean"] = { fg = r.boolean },
    ["@number"] = { fg = r.number },
    ["@number.float"] = { fg = r.number },

    ["@type"] = { fg = r.type },
    ["@type.builtin"] = { fg = r.type_builtin },
    ["@type.definition"] = { fg = r.type },

    ["@attribute"] = { fg = r.decorator },
    ["@attribute.builtin"] = { fg = r.decorator },
    ["@property"] = { fg = r.property },

    ["@function"] = { fg = r.func },
    ["@function.builtin"] = { fg = r.func },
    ["@function.call"] = { fg = r.func },
    ["@function.macro"] = { fg = r.func },
    ["@function.method"] = { fg = r.func },
    ["@function.method.call"] = { fg = r.func },
    ["@constructor"] = { fg = r.type },
    ["@operator"] = { fg = r.operator },

    ["@keyword"] = { fg = r.keyword },
    ["@keyword.coroutine"] = { fg = r.keyword_control },
    ["@keyword.function"] = { fg = r.keyword },
    ["@keyword.operator"] = { fg = r.keyword },
    ["@keyword.import"] = { fg = r.keyword_control },
    ["@keyword.type"] = { fg = r.keyword },
    ["@keyword.modifier"] = { fg = r.keyword },
    ["@keyword.repeat"] = { fg = r.keyword_control },
    ["@keyword.return"] = { fg = r.keyword_control },
    ["@keyword.debug"] = { fg = r.keyword_control },
    ["@keyword.exception"] = { fg = r.keyword_control },
    ["@keyword.conditional"] = { fg = r.keyword_control },
    ["@keyword.conditional.ternary"] = { fg = r.operator },
    ["@keyword.directive"] = { fg = r.keyword_control },
    ["@keyword.directive.define"] = { fg = r.keyword_control },

    ["@punctuation"] = { fg = r.punctuation },
    ["@punctuation.delimiter"] = { fg = r.punctuation },
    ["@punctuation.bracket"] = { fg = r.punctuation },
    ["@punctuation.special"] = { fg = r.keyword }, -- ${ } in template strings (VS Code: blue)

    ["@comment"] = { fg = r.comment },
    ["@comment.documentation"] = { fg = r.comment },
    ["@comment.error"] = { fg = r.bg, bg = r.error, bold = true },
    ["@comment.warning"] = { fg = r.bg, bg = r.warn, bold = true },
    ["@comment.todo"] = { fg = r.bg, bg = r.info, bold = true },
    ["@comment.note"] = { fg = r.bg, bg = r.hint, bold = true },

    ["@markup.strong"] = { bold = true },
    ["@markup.italic"] = { italic = true },
    ["@markup.strikethrough"] = { strikethrough = true },
    ["@markup.underline"] = { underline = true },
    ["@markup.heading"] = { fg = r.heading, bold = true },
    ["@markup.quote"] = { fg = r.markup_quote, italic = true },
    ["@markup.math"] = { fg = r.number },
    ["@markup.link"] = { fg = r.markup_link },
    ["@markup.link.label"] = { fg = r.markup_link },
    ["@markup.link.url"] = { fg = r.link, underline = true },
    ["@markup.raw"] = { fg = r.markup_code },
    ["@markup.raw.block"] = { fg = r.fg },
    ["@markup.list"] = { fg = r.markup_list },
    ["@markup.list.checked"] = { fg = r.ok },
    ["@markup.list.unchecked"] = { fg = r.fg_muted },

    ["@diff.plus"] = { fg = r.git_add },
    ["@diff.minus"] = { fg = r.git_delete },
    ["@diff.delta"] = { fg = r.git_change },

    ["@tag"] = { fg = r.tag },
    ["@tag.builtin"] = { fg = r.tag },
    ["@tag.attribute"] = { fg = r.attribute },
    ["@tag.delimiter"] = { fg = r.fg_muted }, -- VS Code: punctuation.definition.tag #808080
  }
end
