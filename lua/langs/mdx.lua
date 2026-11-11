---MDX language pack: mdx_analyzer + prettier + mdx.nvim (an after/plugin with
---markdown query injections — no lua module to require).
---@type LangPack
return {
  lsp = { mdx_analyzer = {} },
  formatters = { mdx = { "prettier" } },
  packs = { { src = "davidmh/mdx.nvim" } },
  mason = { "mdx-analyzer", "prettier" },
  setup = function()
    vim.filetype.add({ extension = { mdx = "mdx" } })
  end,
}
