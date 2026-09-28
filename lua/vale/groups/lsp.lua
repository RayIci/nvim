---LSP semantic tokens and LSP UI. Token groups link to the treesitter capture
---for the same construct, so a token keeps its colour when a server attaches.
---@param r ValeRoles
---@return table<string, vim.api.keyset.highlight>
return function(r)
  local link = function(to)
    return { link = to }
  end
  return {
    -- Semantic token types (:h lsp-semantic-highlight)
    ["@lsp.type.class"] = link("@type"),
    ["@lsp.type.comment"] = {}, -- keep treesitter's comment highlights (TODO markers etc.)
    ["@lsp.type.decorator"] = link("@attribute"),
    ["@lsp.type.enum"] = link("@type"),
    ["@lsp.type.enumMember"] = link("@constant"),
    ["@lsp.type.event"] = link("@property"),
    ["@lsp.type.function"] = link("@function"),
    ["@lsp.type.interface"] = link("@type"),
    ["@lsp.type.keyword"] = link("@keyword"),
    ["@lsp.type.macro"] = link("@function.macro"),
    ["@lsp.type.method"] = link("@function.method"),
    ["@lsp.type.modifier"] = link("@keyword.modifier"),
    ["@lsp.type.namespace"] = link("@module"),
    ["@lsp.type.number"] = link("@number"),
    ["@lsp.type.operator"] = link("@operator"),
    ["@lsp.type.parameter"] = link("@variable.parameter"),
    ["@lsp.type.property"] = link("@property"),
    ["@lsp.type.regexp"] = link("@string.regexp"),
    ["@lsp.type.string"] = link("@string"),
    ["@lsp.type.struct"] = link("@type"),
    ["@lsp.type.type"] = link("@type"),
    ["@lsp.type.typeParameter"] = link("@type"),
    ["@lsp.type.variable"] = {}, -- let treesitter decide (builtin, member, parameter…)

    -- Server-specific token types
    ["@lsp.type.builtinType"] = link("@type.builtin"), -- rust-analyzer
    ["@lsp.type.selfKeyword"] = link("@variable.builtin"), -- rust-analyzer
    ["@lsp.type.selfTypeKeyword"] = link("@variable.builtin"),
    ["@lsp.type.lifetime"] = link("@keyword.modifier"),
    ["@lsp.type.formatSpecifier"] = link("@string.escape"),
    ["@lsp.type.escapeSequence"] = link("@string.escape"),
    ["@lsp.type.attributeBracket"] = link("@punctuation.bracket"),
    ["@lsp.type.field"] = link("@variable.member"), -- roslyn
    ["@lsp.type.constant"] = link("@constant"),
    ["@lsp.type.extensionMethod"] = link("@function.method"),
    ["@lsp.type.recordClass"] = link("@type"),
    ["@lsp.type.recordStruct"] = link("@type"),
    ["@lsp.type.delegate"] = link("@type"),
    ["@lsp.type.stringEscapeCharacter"] = link("@string.escape"),
    ["@lsp.type.stringVerbatim"] = link("@string"),
    ["@lsp.type.controlKeyword"] = link("@keyword.conditional"),
    ["@lsp.type.preprocessorKeyword"] = link("@keyword.directive"),
    ["@lsp.type.xmlDocCommentName"] = link("@tag"),
    ["@lsp.type.xmlDocCommentAttributeName"] = link("@tag.attribute"),
    ["@lsp.type.xmlDocCommentDelimiter"] = link("@comment"),
    ["@lsp.type.xmlDocCommentText"] = link("@comment"),
    ["@lsp.type.annotation"] = link("@attribute"), -- jdtls
    ["@lsp.type.annotationMember"] = link("@variable.parameter"),
    ["@lsp.type.record"] = link("@type"),
    ["@lsp.type.recordComponent"] = link("@variable.member"),

    -- Modifiers
    ["@lsp.mod.deprecated"] = { strikethrough = true },
    ["@lsp.mod.readonly"] = {},
    ["@lsp.typemod.variable.readonly"] = link("@constant"), -- VS Code: variable.other.constant
    ["@lsp.typemod.variable.defaultLibrary"] = link("@variable.builtin"),
    ["@lsp.typemod.function.defaultLibrary"] = link("@function.builtin"),
    ["@lsp.typemod.method.defaultLibrary"] = link("@function.builtin"),
    ["@lsp.typemod.keyword.controlFlow"] = link("@keyword.conditional"),
    ["@lsp.typemod.keyword.async"] = link("@keyword.coroutine"),
    -- VS Code maps `readonly` (Java/TS `final`/`const` fields) to the constant colour
    ["@lsp.typemod.property.readonly"] = link("@constant"),

    -- LSP UI
    LspReferenceText = { bg = r.word_highlight },
    LspReferenceRead = { bg = r.word_highlight },
    LspReferenceWrite = { bg = r.word_highlight, underline = true },
    LspReferenceTarget = { link = "LspReferenceText" },
    LspInlayHint = { fg = r.inlay_fg, bg = r.inlay_bg },
    LspCodeLens = { fg = r.codelens },
    LspCodeLensSeparator = { fg = r.guide },
    LspSignatureActiveParameter = { fg = r.link, bold = true },
    LspInfoBorder = { link = "FloatBorder" },
  }
end
