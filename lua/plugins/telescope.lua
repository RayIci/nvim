---telescope.nvim + fzf-native sorter: fuzzy pickers under <leader>f.
---@class PluginTelescope
local M = {}

function M.setup()
  local telescope = require("telescope")
  telescope.setup({
    defaults = {
      prompt_prefix = "   ",
      selection_caret = " ",
      sorting_strategy = "ascending",
      layout_config = { prompt_position = "top" },
    },
    pickers = {
      find_files = { hidden = true },
    },
  })
  pcall(telescope.load_extension, "fzf")

  local tb = require("telescope.builtin")
  local map = vim.keymap.set
  map("n", "<leader>ff", tb.find_files, { desc = "Find files" })
  map("n", "<leader>fg", tb.live_grep, { desc = "Live grep" })
  map("n", "<leader>fb", tb.buffers, { desc = "Buffers" })
  map("n", "<leader>fh", tb.help_tags, { desc = "Help tags" })
  map("n", "<leader>fr", tb.oldfiles, { desc = "Recent files" })
  map("n", "<leader>fw", tb.grep_string, { desc = "Grep word under cursor" })
  map("n", "<leader>fd", tb.diagnostics, { desc = "Diagnostics" })
  map("n", "<leader>fk", tb.keymaps, { desc = "Keymaps" })
  map("n", "<leader>fs", tb.lsp_dynamic_workspace_symbols, { desc = "Workspace symbols" })
  map("n", "<leader>f.", tb.resume, { desc = "Resume last picker" })
  map("n", "<leader><leader>", tb.buffers, { desc = "Buffers" })
end

return M
