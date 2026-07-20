## Context

The current config wires languages through `lua/langs/*.lua` packs merged by `lua/langs/init.lua` into subsystems that expose `setup()` (ran from `plugins/init.lua`) and `apply()` (ran later by `langs.setup()` with merged pack data). Only `lua` and `python` packs exist. The old config (`~/dotfiles/.config/nvim/lua/code-configs/`) covers ~18 more languages, but its packs also install **plugins**, register **neotest adapters**, contribute **blink completion sources**, and define **keymaps/commands** — none of which the current `LangPack` supports. Plugins here are managed by native `vim.pack` (no lazy loading), declared today only in `config/pack.lua`.

## Goals / Non-Goals

**Goals:**
- Port every old language config as a drop-in `lua/langs/<lang>.lua` pack, keymaps and companion plugins included.
- Extend the framework minimally: `packs` (vim.pack plugin specs + optional build hooks), `test` (neotest adapter), `completion` (blink source contributions).
- Add neotest as a proper subsystem following the existing `setup()`/`apply()` pattern.
- Keep the "adding a language = one file, no core edits" invariant.

**Non-Goals:**
- sonarlint (was disabled upstream — needs Java), omnisharp (roslyn is the C# server), the old copilot stub.
- Lazy loading of language plugins (vim.pack has none; the config is eager by design).
- New languages not present in the old config (e.g. Go — old base treesitter had Go parsers but no Go tooling; parsers only).

## Decisions

### D1: Per-language plugins via a `packs` field on LangPack
`LangPack.packs` is a list of entries `{ src = <vim.pack spec or "owner/name" shorthand>, build? = fun(path) }`. The loader collects them and calls `vim.pack.add()` once during `langs.setup()`, registering a `PackChanged` autocmd for build hooks **before** the `add()` call (markdown-preview's `yarn install`, pymple's `:PympleBuild`). Plugin configuration code lives in the pack's `setup()`, which already runs after all wiring.
- *Alternative considered*: declaring everything centrally in `config/pack.lua` — rejected because it breaks the one-file-per-language invariant the framework spec mandates.
- Ordering note: `vim.pack.add` in `langs.setup()` runs during startup before `VimEnter`, so plugin `plugin/` files still source normally.

### D2: Neotest as a subsystem with `test` field
`LangPack.test` is `fun(): neotest.Adapter|neotest.Adapter[]` (old `register_adapter` signature). New `plugins/neotest.lua`:
- `setup()` — the full `<leader>t` keymap tree from the old config (run/debug/output/summary/navigate/watch groups, `]t`/`[t`/`]T`/`[T`), plus the `q`-to-close autocmd for neotest buffers.
- `apply(adapter_funs)` — resolves adapter functions and calls `require("neotest").setup()` with the old config's options (overseer consumer, rounded floats, summary panel mappings, icons).
neotest + nvim-neotest/nvim-nio go in `config/pack.lua` (core subsystem); per-language adapter plugins (neotest-python, neotest-java, neotest-dotnet) ship in each pack's `packs`.
- *Alternative*: skip neotest — rejected per user decision.

### D3: Blink completion contributions via `completion` field, deferred setup
`LangPack.completion` = `{ providers?: table<string, blink.cmp.SourceProviderConfig>, per_filetype?: table<string, string[]>, default?: string[] }`. `plugins/blink.lua` is restructured to match the conform pattern: `setup()` stores the base config (and keymaps/guards), `apply(completion)` deep-merges pack contributions into `sources` and only then calls `require("blink.cmp").setup()`. LSP capabilities via `blink.cmp.get_lsp_capabilities()` don't require setup to have run, and `vim.lsp.enable` happens after `apply` in `langs.setup()`, so ordering is safe.
Consumers: sql (dadbod source for sql/mysql/plsql), markdown (blink-emoji for markdown/gitcommit), dotnet (easy-dotnet default source). Sources that need `blink.compat` (dadbod) reuse the existing compat provider pattern.

### D4: Language-pack specifics (ports, not redesigns)
- **web**: one `web.lua` pack for ts_ls, cssls, css_variables, cssmodules_ls, tailwindcss, html + prettier + eslint_d/htmlhint. Astro and mdx stay separate packs (separate servers/plugins).
- **java**: jdtls via `vim.lsp.config`/`enable` with java-debug-adapter bundles in `init_options`; nvim-jdtls plugin for `organize_imports`/extract refactors; `:Java` user command (build/clean/test/run/organize/extract*/doc/reloadProject) running build tools through Overseer; DAP launch/attach configs.
- **kotlin**: kotlin_language_server with the SDKMAN Java-21 workaround (KLS 1.3.13 crashes on Java 25's two-digit version) — warn if no Java 21 found; kotlin-debug-adapter; `:Kotlin` command; shares neotest-java.
- **dotnet**: roslyn.nvim + easy-dotnet.nvim (lsp.enabled=false, `vim.lsp.enable("roslyn")`), csharpier with `--stdin-path $FILENAME`, netcoredbg adapters (`coreclr` + `netcoredbg`) with the dll-path builder helpers, `SolutionSelect`/`SolutionAutoSelect` commands + BufEnter auto-select autocmd + `<leader>-s` group, neotest-dotnet, easy-dotnet blink source.
- **python** (LSP unchanged: basedpyright + ruff): linters become `{ "ruff", "mypy" }`; formatters `{ "ruff_format", "ruff_organize_imports", "ruff_fix" }`; add venv-selector.nvim (`<leader>-pp`, telescope picker) whose selection drives terminal venv activation (replacing the convention-based `.venv`/`venv` hook — keep convention as fallback when no venv selected); pymple.nvim; vim-python-pep8-indent; neotest-python (pytest runner).
- **sql**: no LSP; sql_formatter; vim-dadbod-ui/-completion with `<leader>D` group and dbui/dbout/sql buffer-local Plug mappings; dadbod blink source.
- **http**: kulala.nvim with `<leader>h*` request keymaps (buffer-local to http/rest via FileType autocmd, since vim.pack has no `keys` lazy spec), kulala-fmt formatter.
- **markdown**: marksman, markdownlint+prettier, markdown-preview.nvim (`<leader>-m` group), markdown-toc, blink-emoji source.
- **latex**: texlab, tex-fmt, vimtex (WSL SumatraPDF forward-search vs zathura branch preserved), wrapping.nvim.
- **mdx**: `vim.filetype.add` registration, mdx_analyzer, prettier, mdx.nvim.
- Simple packs (bash, docker, json+schemastore, yaml, toml, xml, gradle, make, astro, rust) are direct translations.

### D5: Treesitter base parsers
`plugins/treesitter.lua`'s always-installed list grows with: `gitignore`, `git_rebase`, `git_config`, `gitattributes`, `editorconfig`, `dockerfile`, `make`, `xml`, `http`, `c`, `lua`, `luadoc`. Language packs still declare their own (the merged list is deduped).

### D6: Keymap namespace
Language-specific groups reuse the old config's (all currently free): `<leader>-` per-language prefix (`-m` markdown, `-p` python, `-s` C# solution), `<leader>D` database, `<leader>h` HTTP, `<leader>t` tests. Which-key group labels registered in each pack's `setup()`.

## Risks / Trade-offs

- [All language plugins load eagerly (vim.pack has no lazy loading)] → startup cost bounded: heavy plugins (easy-dotnet, kulala, dadbod-ui) do most work on first command/FileType; measure with the existing startup-time tooling and gate config work behind FileType autocmds inside pack `setup()` where noticeable.
- [markdown-preview build needs yarn; pymple needs `:PympleBuild`] → build hooks via D1; failures are non-fatal (plugin simply inactive) and surfaced by `vim.pack` update UI.
- [KLS crashes without Java 21] → ported SDKMAN detection warns with the exact `sdk install` command instead of silently failing.
- [roslyn.nvim + easy-dotnet interplay is fragile (who starts roslyn)] → keep the old config's proven arrangement verbatim: easy-dotnet `lsp.enabled = false`, roslyn.nvim owns the server.
- [mypy alongside basedpyright yields duplicate type diagnostics] → accepted per user decision; both run, mypy only as save-time nvim-lint linter.
- [~20 new plugins + ~35 mason tools on first launch] → mason-tool-installer installs in background; treesitter parsers install idempotently; first launch is slow once.

## Migration Plan

Implement framework extensions first (loader fields, neotest, blink restructure) — the existing lua/python packs must keep working with zero changes before any new pack lands. Then add packs tier by tier (simple → medium → heavy), verifying `nvim --headless` starts cleanly after each tier. Rollback = delete the offending `lua/langs/<lang>.lua` (drop-in invariant).

## Open Questions

- None blocking. (tombi LSP for TOML assumes the mason `tombi` package provides both LSP and formatter, as in the old config.)
