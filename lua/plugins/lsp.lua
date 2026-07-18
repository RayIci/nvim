---Native LSP wiring: global capabilities, LspAttach keymaps, vim.diagnostic.
---Server enablement happens in the langs loader (vim.lsp.enable there);
---nvim-lspconfig is on the rtp purely for its lsp/<server>.lua definitions.
---@class PluginLsp
local M = {}

local function on_attach_keymaps(ev)
  ---@param mode string|string[]
  ---@param lhs string
  ---@param rhs function
  ---@param desc string
  local function map(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { buffer = ev.buf, desc = desc })
  end

  local tb = require("telescope.builtin")
  map("n", "gd", tb.lsp_definitions, "Goto definition")
  map("n", "gD", vim.lsp.buf.declaration, "Goto declaration")
  map("n", "grr", tb.lsp_references, "References")
  map("n", "gri", tb.lsp_implementations, "Goto implementation")
  map("n", "grt", tb.lsp_type_definitions, "Goto type definition")
  map("n", "grn", vim.lsp.buf.rename, "Rename symbol")
  map({ "n", "v" }, "gra", vim.lsp.buf.code_action, "Code action")
  map("n", "gO", tb.lsp_document_symbols, "Document symbols")
  map("n", "H", function()
    vim.lsp.buf.hover({ border = "rounded", max_height = 25 })
  end, "Hover docs")
  map("i", "<C-s>", function()
    vim.lsp.buf.signature_help({ border = "rounded" })
  end, "Signature help")
  map("n", "<leader>ci", function()
    local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf })
    vim.lsp.inlay_hint.enable(not enabled, { bufnr = ev.buf })
  end, "Toggle inlay hints")
end

function M.setup()
  -- blink.cmp capabilities for every server
  vim.lsp.config("*", {
    capabilities = require("blink.cmp").get_lsp_capabilities(),
  })

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("config.lsp.attach", { clear = true }),
    callback = on_attach_keymaps,
  })

  -- Diagnostics presentation
  vim.diagnostic.config({
    severity_sort = true,
    update_in_insert = false,
    virtual_text = { source = "if_many", spacing = 2 },
    float = { border = "rounded", source = "if_many" },
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = " ",
        [vim.diagnostic.severity.WARN] = " ",
        [vim.diagnostic.severity.INFO] = " ",
        [vim.diagnostic.severity.HINT] = " ",
      },
    },
  })

  vim.keymap.set("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Line diagnostics" })
  vim.keymap.set("n", "<leader>cq", vim.diagnostic.setqflist, { desc = "Diagnostics to quickfix" })
  -- ]d / [d / ]D / [D are built-in defaults in 0.12; keep them.
end

return M
