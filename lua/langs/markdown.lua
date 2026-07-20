---Markdown language pack: marksman + markdownlint/prettier, browser preview,
---TOC generation, and emoji completion (markdown + gitcommit buffers).
---@type LangPack
return {
  treesitter = { "markdown", "markdown_inline" },
  lsp = { marksman = {} },
  formatters = { markdown = { "markdownlint", "prettier" } },
  linters = { markdown = { "markdownlint" } },
  mason = { "marksman", "markdownlint", "prettier" },
  packs = {
    {
      src = "iamcco/markdown-preview.nvim",
      build = function(path)
        vim.system({ "yarn", "install" }, { cwd = vim.fs.joinpath(path, "app") }):wait()
      end,
    },
    { src = "hedyhli/markdown-toc.nvim" },
    { src = "moyiz/blink-emoji.nvim" },
  },
  completion = {
    -- Global source; should_show_items keeps it out of every other filetype.
    default = { "emoji" },
    providers = {
      emoji = {
        module = "blink-emoji",
        name = "Emoji",
        score_offset = 15,
        opts = { insert = true },
        should_show_items = function()
          return vim.tbl_contains({ "gitcommit", "markdown" }, vim.o.filetype)
        end,
      },
    },
  },
  setup = function()
    vim.g.mkdp_filetypes = { "markdown" }
    require("mtoc").setup({})

    require("which-key").add({
      { "<leader>-", group = "Language" },
      { "<leader>-m", group = "Markdown" },
    })
    vim.keymap.set("n", "<leader>-mm", "<cmd>MarkdownPreview<cr>", { desc = "Preview" })
    vim.keymap.set("n", "<leader>-mt", "<cmd>MarkdownPreviewToggle<cr>", { desc = "Toggle Preview" })
    vim.keymap.set("n", "<leader>-mc", "<cmd>MarkdownPreviewStop<cr>", { desc = "Stop Preview" })
  end,
}
