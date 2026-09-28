---todo-comments.nvim. Its keyword colours come from its config, which links
---to Diagnostic*/Identifier groups by default; vale only pins those anchors.
---@param r ValeRoles
return function(r)
  return {
    TodoBgTODO = { fg = r.fg_on_accent, bg = r.info, bold = true },
    TodoFgTODO = { fg = r.info },
    TodoSignTODO = { fg = r.info },
    TodoBgNOTE = { fg = r.bg, bg = r.hint, bold = true },
    TodoFgNOTE = { fg = r.hint },
    TodoSignNOTE = { fg = r.hint },
    TodoBgFIX = { fg = r.fg_on_accent, bg = r.error, bold = true },
    TodoFgFIX = { fg = r.error },
    TodoSignFIX = { fg = r.error },
    TodoBgWARN = { fg = r.bg, bg = r.warn, bold = true },
    TodoFgWARN = { fg = r.warn },
    TodoSignWARN = { fg = r.warn },
    TodoBgHACK = { fg = r.bg, bg = r.warn, bold = true },
    TodoFgHACK = { fg = r.warn },
    TodoSignHACK = { fg = r.warn },
    TodoBgPERF = { fg = r.fg_on_accent, bg = r.keyword_control, bold = true },
    TodoFgPERF = { fg = r.keyword_control },
    TodoSignPERF = { fg = r.keyword_control },
    TodoBgTEST = { fg = r.fg_on_accent, bg = r.keyword_control, bold = true },
    TodoFgTEST = { fg = r.keyword_control },
    TodoSignTEST = { fg = r.keyword_control },
  }
end
