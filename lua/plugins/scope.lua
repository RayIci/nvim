---scope.nvim: scope listed buffers per tabpage, so bufferline only shows the
---current tab's buffers. Session persistence is handled by auto-session hooks
---(ScopeSaveState / ScopeLoadState) in plugins/auto-session.lua.
---@class PluginScope
local M = {}

function M.setup()
  require("scope").setup({})
end

return M
