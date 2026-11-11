---JSON language pack: jsonls with schemastore schemas + prettier + jsonlint.

---@type LangPack
return {
  -- nvim-treesitter's main branch ships no `jsonc` parser (only json/json5),
  -- and requesting one warns "skipping unsupported language: jsonc"; the json
  -- parser serves the jsonc filetype instead.
  treesitter = { "json5", json = { "json", "jsonc" } },
  lsp = {
    jsonls = {
      before_init = function(_, config)
        config.settings.json.schemas = require("schemastore").json.schemas({
          extra = {
            {
              description = "DAP Config Schema (nvim-dap)",
              fileMatch = { "launch.json", ".vscode/launch.json" },
              name = "launch.json-dap",
              url = "https://codeberg.org/mfussenegger/dapconfig-schema/raw/branch/master/dapconfig-schema.json",
            },
          },
        })
      end,
      settings = {
        json = {
          validate = { enable = true },
        },
      },
    },
  },
  formatters = { json = { "prettier" }, jsonc = { "prettier" } },
  linters = { json = { "jsonlint" } },
  packs = { { src = "b0o/schemastore.nvim" } },
  mason = { "json-lsp", "prettier", "jsonlint" },
}
