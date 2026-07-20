---JSON language pack: jsonls with schemastore schemas + prettier + jsonlint.
---@type LangPack
return {
  treesitter = { "json", "json5", "jsonc" },
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
