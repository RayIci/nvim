---gitsigns.nvim
---@param r ValeRoles
return function(r)
  return {
    GitSignsAdd = { fg = r.git_add },
    GitSignsChange = { fg = r.git_change },
    GitSignsDelete = { fg = r.git_delete },
    GitSignsTopdelete = { fg = r.git_delete },
    GitSignsChangedelete = { fg = r.git_change },
    GitSignsUntracked = { fg = r.git_add },
    GitSignsAddNr = { fg = r.git_add },
    GitSignsChangeNr = { fg = r.git_change },
    GitSignsDeleteNr = { fg = r.git_delete },
    GitSignsAddLn = { bg = r.diff_add },
    GitSignsChangeLn = { bg = r.diff_change },
    GitSignsDeleteLn = { bg = r.diff_delete },
    GitSignsAddInline = { bg = r.diff_add_text },
    GitSignsChangeInline = { bg = r.diff_text },
    GitSignsDeleteInline = { bg = r.diff_delete_text },
    GitSignsAddLnInline = { bg = r.diff_add_text },
    GitSignsChangeLnInline = { bg = r.diff_text },
    GitSignsDeleteLnInline = { bg = r.diff_delete_text },
    GitSignsAddPreview = { bg = r.diff_add },
    GitSignsDeletePreview = { bg = r.diff_delete },
    GitSignsDeleteVirtLn = { bg = r.diff_delete },
    GitSignsDeleteVirtLnInLine = { bg = r.diff_delete_text },
    GitSignsVirtLnum = { fg = r.linenr, bg = r.diff_delete },
    GitSignsCurrentLineBlame = { fg = r.ghost },
    GitSignsStagedAdd = { fg = r.git_add, bold = false },
  }
end
