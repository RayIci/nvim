---vim-illuminate: highlight other references of the symbol under the cursor;
---]] / [[ jump to next/previous reference.
---@class PluginIlluminate
local M = {}

function M.setup()
  require("illuminate").configure({
    providers = { "lsp", "treesitter", "regex" },
    delay = 120,
    large_file_cutoff = 3000,
  })

  vim.keymap.set("n", "]]", function()
    require("illuminate").goto_next_reference(false)
  end, { desc = "Next reference" })
  vim.keymap.set("n", "[[", function()
    require("illuminate").goto_prev_reference(false)
  end, { desc = "Previous reference" })
end

return M
