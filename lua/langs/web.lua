---Web language pack: TypeScript/JavaScript, HTML, CSS (+modules/variables),
---Tailwind. prettier formats, eslint_d lints JS/TS, htmlhint lints HTML.
---@type LangPack
return {
  treesitter = { "html", "css", "javascript", "typescript", "tsx" },
  lsp = {
    ts_ls = {},
    cssls = {},
    css_variables = {},
    cssmodules_ls = {},
    tailwindcss = {},
    html = {},
  },
  formatters = {
    javascript = { "prettier" },
    typescript = { "prettier" },
    javascriptreact = { "prettier" },
    typescriptreact = { "prettier" },
    css = { "prettier" },
    html = { "prettier" },
  },
  linters = {
    javascript = { "eslint_d" },
    typescript = { "eslint_d" },
    javascriptreact = { "eslint_d" },
    typescriptreact = { "eslint_d" },
    html = { "htmlhint" },
  },
  mason = {
    "typescript-language-server",
    "eslint_d",
    "css-lsp",
    "css-variables-language-server",
    "cssmodules-language-server",
    "tailwindcss-language-server",
    "html-lsp",
    "htmlhint",
    "prettier",
  },
}
