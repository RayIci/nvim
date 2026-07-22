---trouble.nvim: structured diagnostics / quickfix / references panels.
---@class PluginTrouble
local M = {}

function M.setup()
  require("trouble").setup({
    modes = {
      symbols = {
        win = { position = "right", size = 0.35 },
      },
    },
  })

  -- Old-config layout: trouble pickers live under <leader>k
  local map = vim.keymap.set
  map("n", "<leader>kd", "<cmd>Trouble diagnostics toggle<cr>", { desc = "Project diagnostics" })
  map("n", "<leader>kD", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", { desc = "Buffer diagnostics" })
  map("n", "<leader>kl", "<cmd>Trouble loclist toggle<cr>", { desc = "Location list" })
  map("n", "<leader>kq", "<cmd>Trouble qflist toggle<cr>", { desc = "Quickfix list" })
  map("n", "<leader>kw", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", { desc = "LSP defs/refs panel" })
  map("n", "<leader>ks", "<cmd>Trouble symbols toggle focus=false<cr>", { desc = "Symbols outline" })
end

return M
