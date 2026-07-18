---bufferline.nvim: top bufferline with diagnostics and pinnable buffers.
---Pin persistence: bufferline stores pins in vim.g.BufferlinePinnedBuffers and
---re-pins on SessionLoadPost; the workspace module round-trips that global.
---@class PluginBufferline
local M = {}

function M.setup()
  require("bufferline").setup({
    options = {
      diagnostics = "nvim_lsp",
      separator_style = "thin",
      always_show_bufferline = true,
      offsets = {
        { filetype = "neo-tree", text = "Files", highlight = "Directory", separator = true },
      },
      groups = {
        items = {
          require("bufferline.groups").builtin.pinned:with({ icon = "󰐃 " }),
        },
      },
    },
  })

  local map = vim.keymap.set
  map("n", "<leader>bp", "<cmd>BufferLineTogglePin<cr>", { desc = "Pin/unpin buffer" })
  map("n", "<leader>bo", "<cmd>BufferLineCloseOthers<cr>", { desc = "Close other buffers" })
  map("n", "<leader>bl", "<cmd>BufferLineCloseLeft<cr>", { desc = "Close buffers to the left" })
  map("n", "<leader>br", "<cmd>BufferLineCloseRight<cr>", { desc = "Close buffers to the right" })
  map("n", "[b", "<cmd>BufferLineMovePrev<cr>", { desc = "Move buffer left" })
  map("n", "]b", "<cmd>BufferLineMoveNext<cr>", { desc = "Move buffer right" })
end

return M
