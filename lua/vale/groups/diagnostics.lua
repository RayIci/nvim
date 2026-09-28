---Diagnostic groups (:h diagnostic-highlights).
---@param r ValeRoles
---@return table<string, vim.api.keyset.highlight>
return function(r)
  local groups = {
    DiagnosticDeprecated = { sp = r.fg_muted, strikethrough = true },
    DiagnosticUnnecessary = { fg = r.unnecessary },
  }
  local severities = { Error = r.error, Warn = r.warn, Info = r.info, Hint = r.hint, Ok = r.ok }
  for name, color in pairs(severities) do
    groups["Diagnostic" .. name] = { fg = color }
    groups["DiagnosticVirtualText" .. name] = { fg = color }
    groups["DiagnosticVirtualLines" .. name] = { fg = color }
    groups["DiagnosticUnderline" .. name] = { sp = color, undercurl = true }
    groups["DiagnosticFloating" .. name] = { fg = color }
    groups["DiagnosticSign" .. name] = { fg = color }
  end
  return groups
end
