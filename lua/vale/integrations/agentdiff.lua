---agentdiff (lua/agentdiff): inline review of agent changes.
---@param r ValeRoles
return function(r)
  return {
    AgentdiffAdd = { bg = r.diff_add },
    AgentdiffDelete = { fg = r.fg_muted, bg = r.diff_delete },
    AgentdiffHint = { fg = r.ghost, italic = true },
    AgentdiffConflict = { bg = r.diff_change },
    AgentdiffTreeFile = { fg = r.warn },
    AgentdiffTreeDir = { fg = r.warn },
  }
end
