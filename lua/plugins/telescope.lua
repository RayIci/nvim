---telescope.nvim + fzf-native sorter: fuzzy pickers under <leader>f.
---@class PluginTelescope
local M = {}

function M.setup()
  local telescope = require("telescope")
  telescope.setup({
    defaults = {
      prompt_prefix = "   ",
      -- Caret and entry_prefix MUST have equal display width: telescope
      -- re-renders rows on selection moves, and a wider caret leaves a
      -- residual space on every visited row (cumulative right-shift).
      selection_caret = "❯ ",
      entry_prefix = "  ",
      sorting_strategy = "ascending",
      layout_config = { prompt_position = "top" },
    },
    pickers = {
      find_files = { hidden = true },
    },
    extensions = {
      -- vim.ui.select provider: makes the DAP config chooser and code actions
      -- render as a proper picker instead of the cmdline inputlist.
      ["ui-select"] = {
        require("telescope.themes").get_dropdown(),
      },
    },
  })
  pcall(telescope.load_extension, "fzf")
  pcall(telescope.load_extension, "ui-select")

  local tb = require("telescope.builtin")
  local map = vim.keymap.set
  map("n", "<leader>ff", tb.resume, { desc = "Resume last picker" })
  map("n", "<leader>fg", tb.live_grep, { desc = "Live grep" })
  map("n", "<leader>fb", tb.buffers, { desc = "Buffers" })
  map("n", "<leader>fh", tb.help_tags, { desc = "Help tags" })
  map("n", "<leader>fr", tb.oldfiles, { desc = "Recent files" })
  map("n", "<leader>fw", tb.grep_string, { desc = "Grep word under cursor" })
  map("n", "<leader>fd", tb.diagnostics, { desc = "Diagnostics" })
  map("n", "<leader>fk", tb.keymaps, { desc = "Keymaps" })
  map("n", "<leader>fs", tb.lsp_dynamic_workspace_symbols, { desc = "Workspace symbols" })
  map("n", "<leader><leader>", tb.find_files, { desc = "Find files" })
end

return M
