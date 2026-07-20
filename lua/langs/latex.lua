---LaTeX language pack: texlab + tex-fmt + vimtex + soft-wrap editing.
---@type LangPack
return {
  treesitter = { "latex", "bibtex" },
  lsp = { texlab = {} },
  formatters = { tex = { "tex-fmt" } },
  mason = { "texlab", "latexindent", "tex-fmt" },
  packs = {
    { src = "lervag/vimtex" },
    { src = "andrewferrier/wrapping.nvim" },
  },
  setup = function()
    vim.g.vimtex_quickfix_mode = 0

    -- vimtex reads viewer options when a tex buffer loads, so setting them
    -- here (post plugin sourcing) is still in time.
    if vim.fn.has("win32") == 1 or (vim.fn.has("unix") == 1 and vim.env.WSLENV ~= nil) then
      -- WSL: forward-search into SumatraPDF on the Windows side
      vim.g.vimtex_view_method = "general"
      vim.g.vimtex_view_general_viewer = "bash"
      vim.g.vimtex_view_general_options =
        '-c "SumatraPDF.exe -reuse-instance -forward-search @tex @line $(wslpath -m @pdf)"'
    else
      vim.g.vimtex_view_method = "zathura"
    end

    require("wrapping").setup({})
  end,
}
