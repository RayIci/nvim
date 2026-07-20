## 1. Framework extensions

- [x] 1.1 Extend `LangPack`/`LangMerged` classes in `lua/langs/init.lua` with `packs` (vim.pack specs + optional `build` per entry), `test` (neotest adapter factory), and `completion` (blink providers/per_filetype/default) fields, merging them in `collect()`
- [x] 1.2 In `langs.setup()`, register a `PackChanged` autocmd for pack-declared build hooks, then install all merged `packs` via one `vim.pack.add()` before subsystem apply calls
- [x] 1.3 Restructure `lua/plugins/blink.lua` to the conform pattern: `setup()` keeps keymap/guard work and stores base config; new `apply(completion)` merges pack completion contributions into `sources` and calls `require("blink.cmp").setup()`; call it from `langs.setup()`
- [x] 1.4 Add neotest + nvim-nio to `lua/config/pack.lua`; create `lua/plugins/neotest.lua` with `setup()` (full `<leader>t` keymap tree, `]t`/`[t`/`]T`/`[T`, q-to-close autocmd) and `apply(adapter_funs)` (resolve factories, neotest.setup with overseer consumer, floats, summary mappings, icons); wire into `plugins/init.lua` and `langs.setup()`
- [x] 1.5 Expand the base parser list in `lua/plugins/treesitter.lua` (git parsers, editorconfig, dockerfile, make, xml, http, c, lua, luadoc) and verify dedup with pack-declared parsers
- [x] 1.6 Verify `nvim --headless "+q"` starts clean and existing lua/python packs still work (LSP attaches, formatter runs)

## 2. Simple language packs

- [x] 2.1 Add `lua/langs/bash.lua` (bashls, shfmt), `lua/langs/docker.lua` (dockerls + compose LS), `lua/langs/make.lua` (mbake)
- [x] 2.2 Add `lua/langs/json.lua` (jsonls + schemastore.nvim pack, prettier, jsonlint), `lua/langs/yaml.lua` (yamlls, prettier, yamllint), `lua/langs/toml.lua` (tombi LSP+format)
- [x] 2.3 Add `lua/langs/xml.lua` (lemminx, csharpier), `lua/langs/gradle.lua` (gradle_ls), `lua/langs/rust.lua` (rust_analyzer, rustfmt, clippy), `lua/langs/astro.lua` (astro LSP)
- [x] 2.4 Verify: open a sample file per language, LSP attaches and formatters run; headless start clean

## 3. Web pack

- [x] 3.1 Add `lua/langs/web.lua`: ts_ls/cssls/css_variables/cssmodules_ls/tailwindcss/html servers, prettier formatters, eslint_d + htmlhint linters, html/css/javascript/typescript/tsx parsers
- [x] 3.2 Add `lua/langs/mdx.lua`: filetype registration, mdx_analyzer, prettier, mdx.nvim pack
- [x] 3.3 Verify a .ts and .mdx buffer end-to-end

## 4. Docs and tools packs

- [x] 4.1 Add `lua/langs/markdown.lua`: marksman, markdownlint+prettier format, markdownlint lint, markdown-preview.nvim (yarn build hook, `<leader>-m` group in setup), markdown-toc, blink-emoji completion source (markdown+gitcommit)
- [x] 4.2 Add `lua/langs/latex.lua`: texlab, tex-fmt, latex parser, vimtex (WSL SumatraPDF / zathura branch), wrapping.nvim
- [x] 4.3 Add `lua/langs/sql.lua`: sql_formatter, dadbod trio packs, `<leader>D` group + dbui/dbout/sql buffer-local mappings via FileType autocmds, dadbod blink source for sql/mysql/plsql
- [x] 4.4 Add `lua/langs/http.lua`: http parser, kulala-fmt, kulala.nvim pack with opts and `<leader>h*` keymaps buffer-local to http/rest
- [x] 4.5 Verify: markdown preview opens, `<leader>DD` toggles DBUI, kulala keymaps present in a .http buffer

## 5. Python enrichment

- [x] 5.1 Update `lua/langs/python.lua`: linters `{ruff, mypy}`, formatters `{ruff_format, ruff_organize_imports, ruff_fix}`, mason adds mypy
- [x] 5.2 Add venv-selector.nvim pack (`<leader>-pp` picker, telescope backend, newline-strip callback), pymple.nvim (build hook), vim-python-pep8-indent; neotest-python adapter (pytest)
- [x] 5.3 Rework terminal hook: venv-selector's selected env activates in new terminals, falling back to `./.venv`/`./venv` convention when none selected
- [x] 5.4 Verify: mypy+ruff diagnostics on save, venv picker works, terminal sources selected venv, nearest pytest test runs via `<leader>tr`

## 6. JVM packs

- [x] 6.1 Add `lua/langs/java.lua`: jdtls with debug-adapter bundles in init_options, google-java-format, checkstyle, nvim-jdtls pack, DAP configs (current file / main-class prompt / attach), neotest-java adapter, `:Java` command with Overseer-backed build/clean/test/run + jdtls refactor subcommands
- [x] 6.2 Add `lua/langs/kotlin.lua`: kotlin_language_server with SDKMAN Java-21 detection + warning, ktlint format+lint, kotlin parser, kotlin-debug-adapter DAP configs, neotest-java adapter (shared, dedup with java), `:Kotlin` command
- [x] 6.3 Verify: jdtls attaches in a Java project, `:Java build` runs through Overseer, KLS starts (or warns without Java 21)

## 7. Dotnet pack

- [x] 7.1 Add `lua/langs/dotnet.lua` part 1 — tooling: roslyn.nvim + easy-dotnet.nvim packs (easy-dotnet lsp disabled, enable roslyn), csharpier with `--stdin-path $FILENAME`, c_sharp parser, easy-dotnet blink completion source, netcoredbg mason install
- [x] 7.2 Part 2 — DAP: `coreclr`/`netcoredbg` adapters and launch/attach/launch-with-args configs with the csproj-root + highest `net*` dll-path helpers
- [x] 7.3 Part 3 — solution management: `SolutionSelect` (telescope picker) and `SolutionAutoSelect` commands, `.cs` BufEnter auto-select autocmd with `vim.g.auto_select_solution` toggle, `<leader>-s` group; neotest-dotnet adapter
- [x] 7.4 Verify: roslyn attaches in a .NET project, solution auto-selects, csharpier formats, DAP launch resolves the dll

## 8. Final verification

- [x] 8.1 Fresh-install check: move `~/.local/share/nvim/site/pack` aside (or on a clean machine), start nvim, confirm all packs + mason tools + parsers install without error, then restore
- [x] 8.2 `:checkhealth` review for lsp, treesitter, neotest, dap; fix reported issues within scope
- [x] 8.3 Startup time comparison vs before (eager plugin loading risk from design D1); apply FileType-gated setup where a pack measurably hurts
- [x] 8.4 Run stylua over new/changed files and update openspec change status
