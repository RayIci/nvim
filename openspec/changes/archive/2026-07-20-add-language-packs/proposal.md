## Why

The old config (`~/dotfiles/.config/nvim`) supported ~18 languages (bash, docker, json, yaml, toml, xml, gradle, make, astro, rust, markdown, mdx, latex, sql, http, web/TS, java, kotlin, C#) via its `code-configs/` system. The rewritten config's `lang-pack-framework` currently ships only `lua` and `python`, so daily work in any other language has no LSP, formatting, linting, debugging, or language tooling. All that behavior already exists in the old config and needs porting into the new one-file-per-language framework.

## What Changes

- Add a language pack under `lua/langs/` for every language in the old config: bash, docker, json, yaml, toml, xml, gradle, make, astro, rust, markdown, mdx, latex, sql, http, web (JS/TS/HTML/CSS/Tailwind), java, kotlin, and dotnet (C#) — each declaring its treesitter parsers, LSP servers, formatters, linters, DAP adapters, mason tools, plugins, and keymaps.
- Extend the `LangPack` framework with:
  - `packs` field — per-language vim.pack plugin specs installed by the loader (e.g. kulala.nvim, vim-dadbod-ui, easy-dotnet.nvim, roslyn.nvim, vimtex, markdown-preview.nvim, venv-selector.nvim, nvim-jdtls).
  - `test` field — neotest adapter registration per language.
  - blink.cmp `apply()` — language packs can contribute completion sources (dadbod for SQL, emoji for markdown/gitcommit, easy-dotnet for C#).
- Add neotest as a new testing subsystem (`plugins/neotest.lua`) with adapters ported for python (neotest-python), java/kotlin (neotest-java), and dotnet (neotest-dotnet), plus test keymaps.
- Enrich the python pack (LSP stays basedpyright): venv-selector.nvim (picker + terminal activation, replacing the convention-based hook), pymple.nvim, vim-python-pep8-indent, mypy added alongside ruff as linters, and ruff formatting extended with `ruff_organize_imports` + `ruff_fix`.
- Port language keymaps and commands: `<leader>-m` markdown preview group, `<leader>D` database group + dbui/dbout buffer maps, `<leader>h` kulala HTTP requests, `<leader>-s` C# solution group with `SolutionSelect`/`SolutionAutoSelect`, `:Java` and `:Kotlin` build/run/test commands (Overseer-backed), `<leader>-pp` venv picker.
- Expand the always-installed treesitter base parsers with common ones: `gitignore`, `git_rebase`, `git_config`, `gitattributes`, `editorconfig`, `dockerfile`, `make`, `xml`, `http`, plus everything packs declare.
- Not ported: sonarlint (was disabled — requires Java), old copilot stub (superseded by copilot.lua), omnisharp (roslyn is the chosen C# server).

## Capabilities

### New Capabilities
- `language-packs`: the concrete per-language packs (which LSP/formatter/linter/DAP/plugins/keymaps each of the 18 languages gets) and their end-to-end behavior.
- `testing`: neotest-based test running — subsystem setup, per-language adapter registration via the framework, and test keymaps.

### Modified Capabilities
- `lang-pack-framework`: the `LangPack` class gains `packs` (per-language vim.pack plugins) and `test` (neotest adapter) fields; blink.cmp gains an `apply()` so packs can contribute completion sources; python example pack requirement updated (venv-selector, mypy).
- `editing-experience`: the treesitter requirement gains an always-installed base parser set (git parsers, editorconfig, dockerfile, make, etc.) on top of pack-declared parsers.

## Impact

- **New files**: ~19 `lua/langs/*.lua` packs, `lua/plugins/neotest.lua`.
- **Modified files**: `lua/langs/init.lua` (new fields, packs installation), `lua/langs/python.lua`, `lua/plugins/blink.lua` (apply()), `lua/plugins/treesitter.lua` (base parsers), `lua/config/pack.lua` (neotest + shared deps), `lua/plugins/init.lua` (neotest setup ordering).
- **Dependencies**: ~20 new plugins (neotest + 3 adapters, roslyn.nvim, easy-dotnet.nvim, nvim-jdtls, kulala.nvim, vim-dadbod trio, vimtex, wrapping.nvim, markdown-preview.nvim, markdown-toc.nvim, mdx.nvim, schemastore.nvim, venv-selector.nvim, pymple.nvim, vim-python-pep8-indent, blink-emoji.nvim); ~35 mason tools installed on demand.
- **Environment**: kotlin-language-server needs a Java 21 (SDKMAN workaround ported); markdown-preview needs yarn at build; JVM/.NET tooling assumes their SDKs are on PATH.
