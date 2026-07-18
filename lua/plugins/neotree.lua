---neo-tree.nvim: file explorer sidebar.
---@class PluginNeotree
local M = {}

function M.setup()
  require("neo-tree").setup({
    close_if_last_window = true,
    filesystem = {
      follow_current_file = { enabled = true },
      filtered_items = {
        hide_dotfiles = false,
        hide_by_name = { ".git" },
      },
      use_libuv_file_watcher = true,
    },
    window = { width = 32 },
  })

  vim.keymap.set("n", "<leader>e", "<cmd>Neotree toggle<cr>", { desc = "File explorer" })
  vim.keymap.set("n", "<leader>E", "<cmd>Neotree reveal<cr>", { desc = "Reveal file in explorer" })
end

return M
