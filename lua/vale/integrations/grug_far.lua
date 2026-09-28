---grug-far.nvim
---@param r ValeRoles
return function(r)
  return {
    GrugFarHelpHeader = { fg = r.fg_muted },
    GrugFarHelpHeaderKey = { fg = r.keyword },
    GrugFarHelpWinHeader = { fg = r.fg_bright, bold = true },
    GrugFarHelpWinActionKey = { fg = r.keyword },
    GrugFarHelpWinActionText = { fg = r.fg },
    GrugFarHelpWinActionPrefix = { fg = r.fg_muted },
    GrugFarHelpWinActionDescription = { fg = r.fg_muted },
    GrugFarInputLabel = { fg = r.type, bold = true },
    GrugFarInputPlaceholder = { fg = r.ghost, italic = true },
    GrugFarResultsHeader = { fg = r.keyword_control, bold = true },
    GrugFarResultsStats = { fg = r.fg_muted },
    GrugFarResultsActionMessage = { fg = r.info },
    GrugFarResultsMatch = { fg = r.fg_bright, bg = r.search },
    GrugFarResultsMatchAdded = { fg = r.fg_bright, bg = r.diff_add_text },
    GrugFarResultsMatchRemoved = { fg = r.fg_bright, bg = r.diff_delete_text, strikethrough = true },
    GrugFarResultsCurrentMatch = { fg = r.fg_bright, bg = r.search_current },
    GrugFarResultsPath = { fg = r.link, underline = true },
    GrugFarResultsLineNr = { fg = r.linenr },
    GrugFarResultsColumnNr = { fg = r.linenr },
    GrugFarResultsNumberLabel = { fg = r.number },
    GrugFarResultsNumbersSeparator = { fg = r.fg_muted },
    GrugFarResultsAddIndicator = { fg = r.git_add },
    GrugFarResultsRemoveIndicator = { fg = r.git_delete },
    GrugFarResultsChangeIndicator = { fg = r.git_change },
    GrugFarResultsDiffSeparatorIndicator = { fg = r.fg_muted },
    GrugFarResultsCmdHeader = { fg = r.fg_muted },
    GrugFarResultsLongLineStr = { fg = r.fg_muted },
  }
end
