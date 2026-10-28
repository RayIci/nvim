# Tasks

## 1. Loader

- [x] 1.1 `lua/langs/init.lua`: merge `treesitter` entries of both forms into `{ parsers, filetypes }` (explicit lists unioned, explicit over bare) and update the `LangPack`/`LangMerged` annotations; verify the merged value in a headless session contains `c_sharp` in `parsers` and the declared lists in `filetypes`
- [x] 1.2 `lua/plugins/treesitter.lua`: install `parsers`, register explicit lists, replace the pattern-based autocmd with a FileType callback that resolves the parser via `get_lang` and applies the explicit/bare rule; verify startup shows no errors

## 2. Packs

- [x] 2.1 dotnet `c_sharp = { "cs", "csharp" }`, bash `bash = { "bash", "sh" }`, web `javascript`/`tsx` lists, latex `latex = {}` + `bibtex = { "bib" }`, json `json = { "json", "jsonc" }` (drop the load-time register); verify `:lua =vim.treesitter.highlighter.active[0] ~= nil` per filetype below

## 3. Verification

- [x] 3.1 Headless check: treesitter active for `cs`, `sh`, `typescriptreact`, `jsonc`, `bib`, `gitconfig`, `python`, `markdown`; inactive for `tex` (vimtex syntax active instead) and for a `neo-tree`/`qf` buffer; no startup errors
- [x] 3.2 `openspec validate fix-treesitter-filetype-mapping --strict`
