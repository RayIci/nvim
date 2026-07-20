---Rust language pack: rust-analyzer + rustfmt + clippy.
---@type LangPack
return {
  treesitter = { "rust" },
  lsp = { rust_analyzer = {} },
  formatters = { rust = { "rustfmt" } },
  linters = { rust = { "clippy" } },
  mason = { "rust-analyzer" },
}
