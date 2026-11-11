---guess-indent.nvim: adopt each file's existing indent style automatically.
---@class PluginGuessIndent
local M = {}

---@type (string|PackSpec)[]
M.spec = {
  "NMAC427/guess-indent.nvim",
}

function M.setup()
  require("guess-indent").setup({})
end

return M
