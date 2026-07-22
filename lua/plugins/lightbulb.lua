---nvim-lightbulb: sign-only code-action availability indicator.
---@class PluginLightbulb
local M = {}

function M.setup()
  require("nvim-lightbulb").setup({
    sign = { enabled = true, text = "💡" },
    virtual_text = { enabled = false },
    float = { enabled = false },
    status_text = { enabled = false },
    number = { enabled = false },
    line = { enabled = false },
    autocmd = {
      enabled = true,
      updatetime = -1,
      events = { "CursorHold", "CursorHoldI" },
    },
    ignore = {
      ft = {
        "neo-tree",
        "Trouble",
        "trouble",
        "toggleterm",
        "lazy",
        "mason",
        "qf",
        "help",
      },
    },
  })
end

return M
