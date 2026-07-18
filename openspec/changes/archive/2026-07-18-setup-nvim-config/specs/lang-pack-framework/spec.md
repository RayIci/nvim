## ADDED Requirements

### Requirement: One file registers a complete language
The configuration SHALL provide a loader (`lua/langs/init.lua`) that automatically discovers every `lua/langs/<language>.lua` file and wires its declared `treesitter`, `lsp`, `formatters`, `linters`, `dap`, and `mason` fields into nvim-treesitter, `vim.lsp.config`/`vim.lsp.enable`, conform.nvim, nvim-lint, nvim-dap, and mason-tool-installer respectively. Adding a language MUST require creating exactly one file with no edits to core config.

#### Scenario: Drop-in language file
- **WHEN** a new file `lua/langs/go.lua` returning the spec table is created and Neovim restarts
- **THEN** the Go LSP attaches to Go buffers, its formatter/linter run for the `go` filetype, its mason tools install, and its treesitter parser is available — with no other file modified

#### Scenario: All fields optional
- **WHEN** a language file declares only `lsp` and `mason` (no dap, linters, or formatters)
- **THEN** the loader wires the declared fields and skips the missing ones without error

### Requirement: Fully typed custom modules
All custom Lua modules (config, prefs, workspace-state, langs loader, language packs) SHALL carry LuaCATS annotations — a `---@class` definition for the language-pack spec table and other structured data, `---@param`/`---@return` on every function — so lua_ls type-checks the config itself, with lazydev.nvim providing Neovim runtime and plugin typings.

#### Scenario: Type error surfaces while editing config
- **WHEN** a language pack file assigns a string to a field typed as a table in the pack spec class
- **THEN** lua_ls reports a type diagnostic in that buffer

### Requirement: Example language packs prove the framework
The configuration SHALL ship with working language packs for `lua` (lua_ls + stylua, lazydev neovim runtime awareness) and `python` (basedpyright or pyright + ruff format/lint + debugpy DAP).

#### Scenario: Python end-to-end
- **WHEN** a Python file is opened after installation completes
- **THEN** the Python LSP attaches, diagnostics appear, format-on-demand uses ruff, and `nvim-dap` can launch a debugpy session
