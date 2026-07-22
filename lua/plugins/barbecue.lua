---barbecue.nvim: VSCode-style winbar breadcrumbs of the symbol path at the
---cursor, backed by nvim-navic (which reads LSP documentSymbol). barbecue owns
---navic attachment (attach_navic) and refreshes the bar on its own autocmds, so
---the breadcrumb follows the cursor. It only renders in windows showing a
---normal file buffer; the exclude list additionally silences known plugin
---panels so the bar never shows in neo-tree, terminals, or other tool windows.
---@class PluginBarbecue
local M = {}

-- Filetypes that must never show the breadcrumb (in addition to barbecue's
-- buftype gate, which already excludes terminals/prompt/nofile from rendering).
local exclude_filetypes = {
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
  "sidekick_terminal",
  "NeogitStatus",
  "octo",
}

function M.setup()
  require("barbecue").setup({
    attach_navic = true, -- barbecue manages navic's LSP attachment
    create_autocmd = true, -- update the winbar on cursor/LSP events
    -- Non-code windows: keep the breadcrumb off plugin panels and terminals.
    exclude_filetypes = exclude_filetypes,
  })

  -- barbecue checks exclusion synchronously but writes the winbar in a deferred
  -- vim.schedule callback that does NOT re-check exclusion (see barbecue/ui.lua
  -- M.update). When a terminal opens as a split off a code window, barbecue's
  -- update runs before the buffer becomes a terminal, so the deferred write
  -- still paints a breadcrumb — and it lands after any synchronous clear. We
  -- clear the winbar for terminal/excluded windows from our own vim.schedule so
  -- it is queued after barbecue's render (schedule callbacks run FIFO) and wins.
  local excluded_ft = {}
  for _, ft in ipairs(exclude_filetypes) do
    excluded_ft[ft] = true
  end

  vim.api.nvim_create_autocmd({ "TermOpen", "BufWinEnter", "BufEnter", "FileType" }, {
    group = vim.api.nvim_create_augroup("config.barbecue.winbar_clear", { clear = true }),
    callback = function(ev)
      -- Non-empty buftype (terminal, nofile, prompt, …) or an excluded
      -- filetype means barbecue must not render here.
      if vim.bo[ev.buf].buftype ~= "" or excluded_ft[vim.bo[ev.buf].filetype] then
        vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(ev.buf) then
            return
          end
          for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
            vim.wo[win].winbar = ""
          end
        end)
      end
    end,
  })
end

return M
