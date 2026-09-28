---copilot.lua
---@param r ValeRoles
return function(r)
  return {
    CopilotSuggestion = { fg = r.ghost, italic = true },
    CopilotAnnotation = { fg = r.ghost, italic = true },
  }
end
