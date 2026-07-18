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
      providers = {
        lazydev = {
          name = "LazyDev",
          module = "lazydev.integrations.blink",
          score_offset = 100,
        },
      },
    },
    snippets = { preset = "default" }, -- native vim.snippet + friendly-snippets
    fuzzy = { implementation = "prefer_rust_with_warning" },
  })
end

return M
