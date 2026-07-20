---neogit: Magit-style git UI in a floating window, with diffview as the
---diff backend and telescope as the picker.
---@class PluginNeogit
local M = {}

function M.setup()
  require("neogit").setup({
    kind = "floating",
    integrations = {
      diffview = true,
      telescope = true,
    },
    signs = {
      hunk = { "", "" },
      item = { ">", "v" },
      section = { ">", "v" },
    },
  })

  local map = vim.keymap.set
  map("n", "<leader>gn", function()
    require("neogit").open()
  end, { desc = "Neogit status" })
  map("n", "<leader>gc", function()
    require("neogit").open({ "commit" })
  end, { desc = "Neogit commit" })
  map("n", "<leader>gp", function()
    require("neogit").open({ "push" })
  end, { desc = "Neogit push" })
  map("n", "<leader>gP", function()
    require("neogit").open({ "pull" })
  end, { desc = "Neogit pull" })
end

return M
