---guess-indent.nvim: adopt each file's existing indent style automatically.
---@class PluginGuessIndent
local M = {}

function M.setup()
  require("guess-indent").setup({})
end

return M
