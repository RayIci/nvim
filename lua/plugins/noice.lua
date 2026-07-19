---noice.nvim: cmdline popup and message routing only. LSP hover uses Neovim's
---native treesitter markdown rendering and signature help is owned by blink.cmp,
---so all noice LSP handlers/overrides stay disabled (see plugins/render-markdown).
---@class PluginNoice
local M = {}

function M.setup()
  require("noice").setup({
    lsp = {
      hover = { enabled = false },
      signature = { enabled = false },
    },
    -- Classic bottom-row cmdline (noice-rendered), not the centered popup
    cmdline = { view = "cmdline" },
    routes = {
      -- Surface mode messages (macro "recording @x") that noice would swallow
      { view = "notify", filter = { event = "msg_showmode" } },
    },
    presets = {
      bottom_search = true,
      long_message_to_split = true,
    },
  })

  vim.keymap.set("n", "<leader>un", "<cmd>NoiceDismiss<cr>", { desc = "Dismiss notifications" })
  vim.keymap.set("n", "<leader>fn", "<cmd>Noice telescope<cr>", { desc = "Notification history" })
end

return M
