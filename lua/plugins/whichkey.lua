---which-key.nvim: discoverable keymaps with named leader groups.
---@class PluginWhichKey
local M = {}

function M.setup()
  local wk = require("which-key")
  wk.setup({
    preset = "modern",
  })

  wk.add({
    { "<leader>a", group = "ai" },
    { "<leader>b", group = "buffers" },
    { "<leader>c", group = "code" },
    { "<leader>d", group = "debug" },
    { "<leader>f", group = "find" },
    { "<leader>g", group = "git" },
    { "<leader>o", group = "tasks" },
    { "<leader>p", group = "plugins" },
    { "<leader>q", group = "session" },
    { "<leader>s", group = "search/replace" },
    { "<leader>T", group = "terminal" },
    { "<leader>u", group = "ui/toggles" },
    { "<leader>x", group = "diagnostics/close" },
  })
end

return M
