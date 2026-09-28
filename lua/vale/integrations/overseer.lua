---overseer.nvim
---@param r ValeRoles
return function(r)
  return {
    OverseerPENDING = { fg = r.fg_muted },
    OverseerRUNNING = { fg = r.accent },
    OverseerSUCCESS = { fg = r.ok },
    OverseerCANCELED = { fg = r.warn },
    OverseerFAILURE = { fg = r.error },
    OverseerDISPOSED = { fg = r.fg_muted },
    OverseerTask = { fg = r.fg_bright, bold = true },
    OverseerTaskBorder = { fg = r.border_float },
    OverseerOutput = { fg = r.fg },
    OverseerComponent = { fg = r.type },
    OverseerField = { fg = r.property },
  }
end
