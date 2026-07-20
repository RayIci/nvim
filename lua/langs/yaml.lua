---YAML language pack: yamlls + prettier + yamllint.
---@type LangPack
return {
  treesitter = { "yaml" },
  lsp = { yamlls = {} },
  formatters = { yaml = { "prettier" } },
  linters = { yaml = { "yamllint" } },
  mason = { "yaml-language-server", "yamllint", "prettier" },
}
