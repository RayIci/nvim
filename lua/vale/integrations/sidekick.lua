---sidekick.nvim (next-edit suggestions shown as inline diffs)
---@param r ValeRoles
return function(r)
  return {
    SidekickDiffAdd = { bg = r.diff_add_text },
    SidekickDiffDelete = { bg = r.diff_delete_text },
    SidekickDiffContext = { bg = r.diff_change },
    SidekickSign = { fg = r.accent },
    SidekickLocFile = { fg = r.fg_bright },
    SidekickLocRow = { fg = r.linenr },
    SidekickLocCol = { fg = r.linenr },
    SidekickLocNum = { fg = r.number },
    SidekickLocDelim = { fg = r.fg_muted },
    SidekickCliAttached = { fg = r.ok },
    SidekickCliStarted = { fg = r.warn },
    SidekickCliInstalled = { fg = r.fg_muted },
    SidekickCliMissing = { fg = r.error },
  }
end
