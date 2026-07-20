---barbecue.nvim: VSCode-style winbar breadcrumbs of the symbol path at the
---cursor, backed by nvim-navic (which reads LSP documentSymbol). barbecue owns
---navic attachment (attach_navic) and refreshes the bar on its own autocmds, so
---the breadcrumb follows the cursor. It only renders in windows showing a
---normal file buffer; the exclude list additionally silences known plugin
---panels so the bar never shows in neo-tree, terminals, or other tool windows.
---@class PluginBarbecue
local M = {}

function M.setup()
  require("barbecue").setup({
    attach_navic = true, -- barbecue manages navic's LSP attachment
    create_autocmd = true, -- update the winbar on cursor/LSP events
    -- Non-code windows: keep the breadcrumb off plugin panels and terminals.
    -- (barbecue already skips floating and non-normal buffers; this is belt-
    -- and-suspenders for filetypes that use a normal buftype.)
    exclude_filetypes = {
      "netrw",
      "toggleterm",
      "neo-tree",
      "neo-tree-popup",
      "Trouble",
      "trouble",
      "Outline",
      "qf",
      "help",
      "dap-repl",
      "dapui_watches",
      "dapui_stacks",
      "dapui_breakpoints",
      "dapui_scopes",
      "dapui_console",
      "OverseerList",
      "grug-far",
      "copilot-chat",
      "NeogitStatus",
      "octo",
    },
  })
end

return M
