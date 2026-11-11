---nvim-surround: ys / cs / ds surround operations.
---@class PluginSurround
local M = {}

---@type (string|PackSpec)[]
M.spec = {
  "kylechui/nvim-surround",
}

function M.setup()
  require("nvim-surround").setup({})
end

return M
