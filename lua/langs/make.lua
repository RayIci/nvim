---Makefile language pack: mbake formatting.
---@type LangPack
return {
  treesitter = { "make" },
  formatters = { make = { "bake" } },
  mason = { "mbake" },
}
