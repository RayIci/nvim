---vim-dadbod-ui (sql language pack)
---@param r ValeRoles
return function(r)
  return {
    dbui_tables = { fg = r.fg },
    dbui_help = { fg = r.fg_muted },
    dbui_connection_ok = { fg = r.ok },
    dbui_connection_error = { fg = r.error },
    dbui_buffers = { fg = r.accent },
    dbui_saved_query = { fg = r.func },
    NotificationInfo = { fg = r.info },
    NotificationWarning = { fg = r.warn },
    NotificationError = { fg = r.error },
  }
end
