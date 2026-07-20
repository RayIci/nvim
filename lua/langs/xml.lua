---XML language pack: lemminx + csharpier formatting (old-config choice over
---xmlformatter).
---@type LangPack
return {
  treesitter = { "xml" },
  lsp = { lemminx = {} },
  formatters = { xml = { "csharpier" } },
  mason = { "lemminx", "csharpier" },
}
