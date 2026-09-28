---Bash/shell language pack: bashls + shfmt.
---@type LangPack
return {
  treesitter = { bash = { "bash", "sh" } },
  lsp = { bashls = {} },
  formatters = { sh = { "shfmt" }, bash = { "shfmt" } },
  mason = { "bash-language-server", "shfmt" },
}
