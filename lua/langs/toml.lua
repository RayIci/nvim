---TOML language pack: tombi (LSP + formatter).
---@type LangPack
return {
  treesitter = { "toml" },
  lsp = { tombi = {} },
  formatters = { toml = { "tombi" } },
  mason = { "tombi" },
}
