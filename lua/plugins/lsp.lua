---Native LSP wiring: global capabilities, LspAttach keymaps, vim.diagnostic.
---Server enablement happens in the langs loader (vim.lsp.enable there);
---nvim-lspconfig is on the rtp purely for its lsp/<server>.lua definitions.
---@class PluginLsp
local M = {}

---@type (string|PackSpec)[]
M.spec = {
  "neovim/nvim-lspconfig",
}

local function on_attach_keymaps(ev)
  ---@param mode string|string[]
  ---@param lhs string
  ---@param rhs function|string
  ---@param desc string
  local function map(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { buffer = ev.buf, desc = desc })
  end

  -- Snacks LSP pickers jump straight to a single result and list several.
  ---@param source string snacks picker source
  ---@param opts? table
  local function pick(source, opts)
    return function()
      Snacks.picker[source](opts)
    end
  end
  map("n", "gd", pick("lsp_definitions"), "Goto definition")
  map("n", "gD", pick("lsp_declarations"), "Goto declaration")
  map("n", "grr", pick("lsp_references"), "References")
  map("n", "gri", pick("lsp_implementations"), "Goto implementation")
  map("n", "grt", pick("lsp_type_definitions"), "Goto type definition")
  map("n", "grn", vim.lsp.buf.rename, "Rename symbol")
  map({ "n", "v" }, "gra", vim.lsp.buf.code_action, "Code action")
  map("n", "gO", pick("lsp_symbols"), "Document symbols")
  map("n", "H", function()
    vim.lsp.buf.hover({ border = "rounded", max_height = 25 })
  end, "Hover docs")
  -- Signature help lives in blink.cmp (<C-k> toggle); <C-s> is reserved for saving.
  map("n", "<leader>ci", function()
    local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf })
    vim.lsp.inlay_hint.enable(not enabled, { bufnr = ev.buf })
  end, "Toggle inlay hints")

  -- <leader>l: the old-config LSP command tree.
  map("n", "<leader>lk", function()
    vim.lsp.buf.signature_help({ border = "rounded" })
  end, "Signature help")
  map({ "n", "v" }, "<leader>la", vim.lsp.buf.code_action, "Code action")
  -- One list of references and implementations, each item tagged by source
  -- (multi pickers number their sources: 1 = references, 2 = implementations).
  map("n", "<leader>lf", function()
    local tags = { "ref ", "impl" }
    Snacks.picker({
      title = "References & implementations",
      multi = { "lsp_references", "lsp_implementations" },
      format = function(item, picker)
        local ret = { { tags[item.source_id] or "    ", "SnacksPickerSpecial" }, { " " } }
        return vim.list_extend(ret, require("snacks.picker.format").file(item, picker))
      end,
    })
  end, "LSP finder (refs + impls)")
  map("n", "<leader>lr", vim.lsp.buf.rename, "Rename symbol")
  map("n", "<leader>lo", "<cmd>Trouble symbols toggle focus=false<cr>", "Symbol outline")

  -- Diagnostics
  map("n", "<leader>ldd", vim.diagnostic.open_float, "Line diagnostics")
  map("n", "<leader>ldb", function()
    Snacks.picker.diagnostics_buffer()
  end, "Buffer diagnostics")
  map("n", "<leader>ldw", pick("diagnostics"), "Workspace diagnostics")
  map("n", "<leader>ldl", vim.diagnostic.setloclist, "Diagnostics to loclist")
  map("n", "<leader>ldq", vim.diagnostic.setqflist, "Diagnostics to quickfix")

  -- Workspace folders
  map("n", "<leader>lwa", vim.lsp.buf.add_workspace_folder, "Add workspace folder")
  map("n", "<leader>lwr", vim.lsp.buf.remove_workspace_folder, "Remove workspace folder")
  map("n", "<leader>lwl", function()
    vim.print(vim.lsp.buf.list_workspace_folders())
  end, "List workspace folders")

  -- Call hierarchy
  map("n", "<leader>lhi", pick("lsp_incoming_calls"), "Incoming calls")
  map("n", "<leader>lho", pick("lsp_outgoing_calls"), "Outgoing calls")

  -- Inlay hints, global toggle (buffer-local toggle stays on <leader>ci)
  map("n", "<leader>li", function()
    local enabled = require("config.prefs").toggle("inlay_hints", false)
    vim.lsp.inlay_hint.enable(enabled)
    vim.notify("Inlay hints " .. (enabled and "enabled" or "disabled"))
  end, "Toggle inlay hints (global, persisted)")

  -- Code lens
  map("n", "<leader>lcr", vim.lsp.codelens.run, "Run code lens")
  map("n", "<leader>lcR", function()
    -- enable(true) re-attaches the provider and triggers a refresh.
    if M.codelens_enabled() then
      vim.lsp.codelens.enable(true, { bufnr = ev.buf })
    end
  end, "Refresh code lenses")
  map("n", "<leader>lct", function()
    local enabled = require("config.prefs").toggle("codelens", true)
    M.apply_codelens(enabled)
    vim.notify("Code lenses " .. (enabled and "enabled" or "disabled"))
  end, "Toggle code lenses (persisted)")
end

---Whether code lenses are on (persisted, default on).
---@return boolean
function M.codelens_enabled()
  return require("config.prefs").get("codelens", true)
end

---Turn code lenses on or off in every buffer with a code-lens server.
---@param enabled boolean
function M.apply_codelens(enabled)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and #vim.lsp.get_clients({ bufnr = buf, method = "textDocument/codeLens" }) > 0 then
      vim.lsp.codelens.enable(enabled, { bufnr = buf })
    end
  end
end

---Enable code lenses for servers that support them, gated on the persisted
---codelens pref (<leader>lct). On 0.12 vim.lsp.codelens.enable(true)
---attaches an auto-refreshing provider (refreshes on buffer changes), so no
---manual refresh-on-events autocmd is needed.
---@param ev vim.api.keyset.create_autocmd.callback_args
local function setup_codelens(ev)
  local client = vim.lsp.get_client_by_id(ev.data.client_id)
  if not client or not client:supports_method("textDocument/codeLens", ev.buf) then
    return
  end
  if M.codelens_enabled() then
    vim.lsp.codelens.enable(true, { bufnr = ev.buf })
  end
end

function M.setup()
  -- blink.cmp completion capabilities for every server (Neovim's defaults,
  -- folding ranges included, are merged in by the client)
  local capabilities = require("blink.cmp").get_lsp_capabilities()

  vim.lsp.config("*", {
    capabilities = capabilities,
  })

  -- Inlay hints follow the persisted <leader>li toggle (default off), for
  -- every buffer including later ones.
  vim.lsp.inlay_hint.enable(require("config.prefs").get("inlay_hints", false))

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("config.lsp.attach", { clear = true }),
    callback = function(ev)
      on_attach_keymaps(ev)
      setup_codelens(ev)
    end,
  })

  -- Diagnostics presentation. update_in_insert follows the persisted
  -- diagnostics-live pref (<leader>ud); linters never run while typing.
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
    vim.notify("Diagnostics display: " .. (live and "updates while typing" or "updates after insert mode"))
  end, { desc = "Toggle live diagnostics (persisted)" })
  -- ]d / [d / ]D / [D are built-in defaults in 0.12; keep them.
end

return M
