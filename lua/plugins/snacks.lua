---@class PluginSnacks
local M = {}

function M.setup()
  require("snacks").setup({
    notifier = {
      enabled = true,
      top_down = false,
      style = "compact",
      timeout = 1000,
      width = { min = 40, max = 0.4 },
      height = { min = 1, max = 0.6 },
      padding = false,
    },
  })
end

return M
