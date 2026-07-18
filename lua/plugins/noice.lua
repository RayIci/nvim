---noice.nvim: markdown-rendered LSP docs, cmdline popup, message routing.
---blink.cmp keeps its own completion documentation window, so noice's
---completion doc override stays disabled.
---@class PluginNoice
local M = {}

function M.setup()
  require("noice").setup({
    lsp = {
      -- Render hover/signature responses through noice (treesitter markdown)
      override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.stylize_markdown"] = true,
      },
      hover = { enabled = true },
      signature = { enabled = true },
    },
    presets = {
      bottom_search = true,
      command_palette = true, -- cmdline popup near the top, like VSCode
      long_message_to_split = true,
      lsp_doc_border = true,
    },
  })

  vim.keymap.set("n", "<leader>un", "<cmd>NoiceDismiss<cr>", { desc = "Dismiss notifications" })
end

return M
