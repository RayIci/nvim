---Native LSP wiring: global capabilities, LspAttach keymaps, vim.diagnostic.
---Server enablement happens in the langs loader (vim.lsp.enable there);
---nvim-lspconfig is on the rtp purely for its lsp/<server>.lua definitions.
---@class PluginLsp
local M = {}

local function on_attach_keymaps(ev)
  ---@param mode string|string[]
  ---@param lhs string
  ---@param rhs function|string
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
  -- Signature help lives in blink.cmp (<C-k> toggle); <C-s> is reserved for saving.
  map("n", "<leader>ci", function()
    local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf })
    vim.lsp.inlay_hint.enable(not enabled, { bufnr = ev.buf })
  end, "Toggle inlay hints")

  -- <leader>l: the old-config LSP command tree (native/telescope equivalents;
  -- lspsaga-only peeks are not ported)
  map("n", "<leader>lk", function()
    vim.lsp.buf.signature_help({ border = "rounded" })
  end, "Signature help")
  map({ "n", "v" }, "<leader>la", vim.lsp.buf.code_action, "Code action")
  map("n", "<leader>lr", vim.lsp.buf.rename, "Rename symbol")
  map("n", "<leader>lo", "<cmd>Trouble symbols toggle focus=false<cr>", "Symbol outline")

  -- Diagnostics
  map("n", "<leader>ldd", vim.diagnostic.open_float, "Line diagnostics")
  map("n", "<leader>ldb", function()
    tb.diagnostics({ bufnr = 0 })
  end, "Buffer diagnostics")
  map("n", "<leader>ldw", tb.diagnostics, "Workspace diagnostics")
  map("n", "<leader>ldl", vim.diagnostic.setloclist, "Diagnostics to loclist")
  map("n", "<leader>ldq", vim.diagnostic.setqflist, "Diagnostics to quickfix")

  -- Workspace folders
  map("n", "<leader>lwa", vim.lsp.buf.add_workspace_folder, "Add workspace folder")
  map("n", "<leader>lwr", vim.lsp.buf.remove_workspace_folder, "Remove workspace folder")
  map("n", "<leader>lwl", function()
    vim.print(vim.lsp.buf.list_workspace_folders())
  end, "List workspace folders")

  -- Call hierarchy
  map("n", "<leader>lhi", tb.lsp_incoming_calls, "Incoming calls")
  map("n", "<leader>lho", tb.lsp_outgoing_calls, "Outgoing calls")

  -- Inlay hints, global toggle (buffer-local toggle stays on <leader>ci)
  map("n", "<leader>li", function()
    local enabled = not vim.lsp.inlay_hint.is_enabled()
    vim.lsp.inlay_hint.enable(enabled)
    vim.notify("Inlay hints " .. (enabled and "enabled" or "disabled"))
  end, "Toggle inlay hints (global)")

  -- Code lens
  map("n", "<leader>lcr", vim.lsp.codelens.run, "Run code lens")
  map("n", "<leader>lcR", function()
    vim.lsp.codelens.refresh({ bufnr = ev.buf })
  end, "Refresh code lenses")
  map("n", "<leader>lct", function()
    vim.g.codelens_enabled = not vim.g.codelens_enabled
    if vim.g.codelens_enabled then
      vim.lsp.codelens.refresh({ bufnr = ev.buf })
      vim.notify("Code lenses enabled")
    else
      vim.lsp.codelens.clear()
      vim.notify("Code lenses disabled")
    end
  end, "Toggle code lenses")
end

---Auto-refresh code lenses for servers that support them (old-config behavior,
---gated on the vim.g.codelens_enabled global toggle).
---@param ev vim.api.keyset.create_autocmd.callback_args
local function setup_codelens(ev)
  local client = vim.lsp.get_client_by_id(ev.data.client_id)
  if not client or not client:supports_method("textDocument/codeLens", ev.buf) then
    return
  end
  vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
    group = vim.api.nvim_create_augroup("config.lsp.codelens." .. ev.buf, { clear = true }),
    buffer = ev.buf,
    callback = function()
      if vim.g.codelens_enabled then
        vim.lsp.codelens.refresh({ bufnr = ev.buf })
      end
    end,
  })
  if vim.g.codelens_enabled then
    vim.lsp.codelens.refresh({ bufnr = ev.buf })
  end
end

function M.setup()
  -- blink.cmp capabilities for every server
  vim.lsp.config("*", {
    capabilities = require("blink.cmp").get_lsp_capabilities(),
  })

  -- Code lenses on by default (old-config default); 'globals' in
  -- sessionoptions carries the toggle across session restores.
  if vim.g.codelens_enabled == nil then
    vim.g.codelens_enabled = true
  end

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("config.lsp.attach", { clear = true }),
    callback = function(ev)
      on_attach_keymaps(ev)
      setup_codelens(ev)
    end,
  })

  -- Diagnostics presentation. update_in_insert follows the persisted
  -- diagnostics-live pref (<leader>ud), like the nvim-lint live runs.
  vim.diagnostic.config({
    severity_sort = true,
    update_in_insert = require("config.prefs").get("diagnostics_live", false),
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
  vim.keymap.set("n", "<leader>ud", function()
    local live = require("config.prefs").toggle("diagnostics_live", false)
    vim.diagnostic.config({ update_in_insert = live })
    vim.notify("Diagnostics refresh: " .. (live and "while typing" or "on open/save/insert-leave"))
  end, { desc = "Toggle live diagnostics (persisted)" })
  -- ]d / [d / ]D / [D are built-in defaults in 0.12; keep them.
end

return M
