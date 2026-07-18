---nvim-autopairs: bracket/quote pairing with treesitter checks.
---Provides the newline-between-brackets expansion (<CR> inside {} indents).
---@class PluginAutopairs
local M = {}

function M.setup()
  require("nvim-autopairs").setup({
    check_ts = true,
  })
end

return M
