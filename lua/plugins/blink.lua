---blink.cmp: completion menu with VSCode-like icons, auto docs, signature help,
---and friendly-snippets. Copilot ghost text is separate (native inline completion).
---@class PluginBlink
local M = {}

---VSCode-style kind icons (nerd font codicons).
---@type table<string, string>
local kind_icons = {
  Text = "󰉿", Method = "󰆧", Function = "󰊕", Constructor = "",
  Field = "󰜢", Variable = "󰀫", Class = "󰠱", Interface = "",
  Module = "", Property = "󰜢", Unit = "󰑭", Value = "󰎠",
  Enum = "", Keyword = "󰌋", Snippet = "", Color = "󰏘",
  File = "󰈙", Reference = "󰈇", Folder = "󰉋", EnumMember = "",
  Constant = "󰏿", Struct = "󰙅", Event = "", Operator = "󰆕",
  TypeParameter = "",
}

function M.setup()
  require("blink.cmp").setup({
    -- C-y accept, C-space docs, C-n/C-p navigate, C-e hide, C-k signature toggle
    keymap = { preset = "default" },
    -- DAP buffers (repl, watches, hover) are prompt buffers, excluded by
    -- blink's default enabled check — allow exactly those through.
    enabled = function()
      if vim.bo.buftype == "prompt" then
        local ok, cmp_dap = pcall(require, "cmp_dap")
        return ok and cmp_dap.is_dap_buffer()
      end
      return vim.b.completion ~= false
    end,
    appearance = {
      nerd_font_variant = "mono",
      kind_icons = kind_icons,
    },
    completion = {
      -- VSCode-like columns: icon | label | kind name
      menu = {
        draw = {
          columns = {
            { "kind_icon" },
            { "label", "label_description", gap = 1 },
            { "kind" },
          },
        },
      },
      -- Render docs automatically while moving through candidates
      documentation = { auto_show = true, auto_show_delay_ms = 150 },
      ghost_text = { enabled = false }, -- reserved for Copilot inline completion
    },
    signature = { enabled = true, window = { show_documentation = true } },
    sources = {
      default = { "lazydev", "lsp", "path", "snippets", "buffer" },
      per_filetype = {
        -- Adapter completions with real kinds via cmp-dap through blink.compat
        -- (old-config stack; blink's omni source loses kind info and renders
        -- a plain overlapping popup instead of the blink menu)
        ["dap-repl"] = { "dap" },
        ["dapui_watches"] = { "dap" },
        ["dapui_hover"] = { "dap" },
      },
      providers = {
        lazydev = {
          name = "LazyDev",
          module = "lazydev.integrations.blink",
          score_offset = 100,
        },
        dap = {
          name = "dap",
          module = "blink.compat.source",
          score_offset = 100,
        },
      },
    },
    snippets = { preset = "default" }, -- native vim.snippet + friendly-snippets
    fuzzy = { implementation = "prefer_rust_with_warning" },
  })

  -- cmp-dap errors when no session (nil capabilities) and may lack "." in its
  -- trigger characters — ported guard from the old config's nilguard fix.
  local ok, cmp_dap = pcall(require, "cmp_dap")
  if ok then
    function cmp_dap:get_trigger_characters()
      local session = require("dap").session()
      if not session or not session.capabilities then
        return { "." }
      end
      local triggers = session.capabilities.completionTriggerCharacters or {}
      if vim.list_contains(triggers, ".") then
        return triggers
      end
      return vim.list_extend({ "." }, triggers)
    end
  end
end

return M
