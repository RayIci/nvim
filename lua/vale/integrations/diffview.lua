---diffview.nvim
---@param r ValeRoles
return function(r)
  return {
    DiffviewNormal = { fg = r.fg, bg = r.bg_chrome },
    DiffviewWinSeparator = { fg = r.border, bg = r.bg_chrome },
    DiffviewEndOfBuffer = { fg = r.bg_chrome },
    DiffviewCursorLine = { bg = r.bg_line },
    DiffviewSignColumn = { bg = r.bg_chrome },
    DiffviewFilePanelTitle = { fg = r.accent, bold = true },
    DiffviewFilePanelCounter = { fg = r.fg_muted },
    DiffviewFilePanelRootPath = { fg = r.fg_bright, bold = true },
    DiffviewFilePanelFileName = { fg = r.fg },
    DiffviewFilePanelSelected = { fg = r.fg_bright, bold = true },
    DiffviewFilePanelPath = { fg = r.fg_muted },
    DiffviewFilePanelInsertions = { fg = r.git_add },
    DiffviewFilePanelDeletions = { fg = r.git_delete },
    DiffviewFilePanelConflicts = { fg = r.warn },
    DiffviewFolderName = { fg = r.fg },
    DiffviewFolderSign = { fg = r.folder },
    DiffviewHash = { fg = r.constant },
    DiffviewReference = { fg = r.accent },
    DiffviewDim1 = { fg = r.fg_muted },
    DiffviewNonText = { fg = r.whitespace },
    DiffviewStatusAdded = { fg = r.git_add },
    DiffviewStatusUntracked = { fg = r.git_add },
    DiffviewStatusModified = { fg = r.git_change },
    DiffviewStatusRenamed = { fg = r.git_change },
    DiffviewStatusCopied = { fg = r.git_change },
    DiffviewStatusTypeChanged = { fg = r.git_change },
    DiffviewStatusUnmerged = { fg = r.warn },
    DiffviewStatusDeleted = { fg = r.git_delete },
    DiffviewStatusBroken = { fg = r.error },
    DiffviewStatusUnknown = { fg = r.fg_muted },
    DiffviewStatusIgnored = { fg = r.fg_muted },
    DiffviewDiffDelete = { fg = r.guide }, -- filler lines ("-----") in the other side
    DiffviewDiffDeleteDim = { fg = r.guide },
  }
end
