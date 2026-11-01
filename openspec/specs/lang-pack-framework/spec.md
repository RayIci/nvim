# lang-pack-framework Specification

## Purpose
Defines the language-pack framework: each language is one `lua/langs/<language>.lua` file declaring its parsers, LSP servers, formatters, linters, debug adapters, tools, tests, completion sources, statusline widgets and extra plugins, and a loader wires those declarations into the matching subsystems.

## Requirements

### Requirement: One file registers a complete language
The configuration SHALL provide a loader (`lua/langs/init.lua`) that automatically discovers every `lua/langs/<language>.lua` file and wires its declared `treesitter`, `lsp`, `formatters`, `linters`, `dap`, and `mason` fields into nvim-treesitter, `vim.lsp.config`/`vim.lsp.enable`, conform.nvim, nvim-lint, nvim-dap, and mason-tool-installer respectively. Every field SHALL be optional. Adding a language MUST require creating exactly one file with no edits to core config.

#### Scenario: Drop-in language file
- **WHEN** a new file `lua/langs/go.lua` returning the spec table is created and Neovim restarts
- **THEN** the Go LSP attaches to Go buffers, its formatter/linter run for the `go` filetype, its mason tools install, and its treesitter parser is available — with no other file modified

#### Scenario: All fields optional
- **WHEN** a language file declares only `lsp` and `mason` (no dap, linters, formatters, packs, test, completion, or statusline)
- **THEN** the loader wires the declared fields and skips the missing ones without error

### Requirement: Pack-declared plugins and setup hook
The loader SHALL accept these optional pack fields:
- `packs` — a list of vim.pack plugin specs (with optional per-entry `build` hooks) that the loader installs via a single `vim.pack.add()` call, registering build hooks on `PackChanged` before installation;
- `setup` — a function the loader runs after all subsystem wiring so packs can integrate with fully-initialized modules (e.g. registering terminal hooks, keymaps, and user commands for plugins declared in `packs`).

#### Scenario: Pack setup runs after wiring
- **WHEN** a pack declares a `setup` function that registers a terminal on_create hook
- **THEN** the function runs during startup after subsystems are wired, and the hook fires when a terminal is later created

#### Scenario: Pack-declared plugin with build hook
- **WHEN** a pack declares `packs = { { src = "iamcco/markdown-preview.nvim", build = <fn> } }` and the plugin is not yet installed
- **THEN** vim.pack installs it during startup and the build hook runs on the install event

### Requirement: Pack-declared tests and completion sources
The loader SHALL accept these optional pack fields:
- `test` — a factory function returning one or more neotest adapters, forwarded to the neotest subsystem's `apply()`;
- `completion` — blink.cmp source contributions (`providers`, `per_filetype`, `default`) merged into blink's sources before its deferred setup.

#### Scenario: Pack-declared completion source
- **WHEN** a pack declares a `completion` table with a provider and a `per_filetype` entry
- **THEN** blink.cmp offers that source in the declared filetypes after startup

### Requirement: Pack-declared statusline widgets
The loader SHALL accept an optional `statusline` pack field: a list of statusline widget specs (each a `render` function returning a string, plus optional `cond`, `icon`, and `color`) that the loader merges and forwards to the lualine subsystem's `apply()`, which surfaces them through a dynamic bridge component.

#### Scenario: Pack-declared statusline widget
- **WHEN** a pack declares `statusline = { { render = fn, cond = fn, icon = "🐍" } }`
- **THEN** the loader forwards it to lualine's `apply()`, and the widget's `render()` output appears in the statusline whenever its `cond` is satisfied and the string is non-empty

### Requirement: Fully typed custom modules
All custom Lua modules (config, prefs, workspace-state, langs loader, language packs) SHALL carry LuaCATS annotations — a `---@class` definition for the language-pack spec table and other structured data, `---@param`/`---@return` on every function — so lua_ls type-checks the config itself, with lazydev.nvim providing Neovim runtime and plugin typings.

#### Scenario: Type error surfaces while editing config
- **WHEN** a language pack file assigns a string to a field typed as a table in the pack spec class
- **THEN** lua_ls reports a type diagnostic in that buffer

### Requirement: Example language packs prove the framework
The configuration SHALL ship with working language packs for `lua` (lua_ls + stylua, lazydev neovim runtime awareness) and `python` (basedpyright + ruff LSP servers, ruff format with organize-imports and fix, ruff + mypy linting, debugpy DAP, venv-selector-driven terminal activation, neotest-python).

#### Scenario: Python end-to-end
- **WHEN** a Python file is opened after installation completes
- **THEN** basedpyright and ruff attach, ruff + mypy diagnostics appear on save, format-on-demand uses ruff, and `nvim-dap` can launch a debugpy session

### Requirement: Treesitter parser-to-filetype mapping
A language pack's `treesitter` field SHALL accept two entry forms, which MAY be mixed in one pack: a bare parser name (e.g. `"python"`), or a `parser = { filetypes }` entry. Every declared parser SHALL be installed. Treesitter highlighting and indentation SHALL be started for a buffer when the `FileType` event fires, by resolving the buffer's filetype to a parser through Neovim's treesitter registry at that moment (after all plugins have registered their mappings).

#### Scenario: Parser name differs from filetype
- **WHEN** a pack declares the bare parser `c_sharp` and a `.cs` file (filetype `cs`) is opened
- **THEN** treesitter highlighting is active in that buffer

#### Scenario: Filetypes without a pack parser
- **WHEN** a buffer of a filetype with no declared parser (e.g. `neo-tree`, `qf`) is created
- **THEN** no treesitter highlighting is started and no error is shown

### Requirement: Bare and explicit parser declarations
A parser declared bare SHALL start on any filetype the registry maps to it. A parser declared with a filetype list SHALL start only on the listed filetypes, and the loader SHALL register that list with the treesitter registry; an empty list installs the parser without starting it on any filetype. When several packs declare the same parser, explicit filetype lists SHALL be combined, and an explicit list SHALL take precedence over a bare declaration.

#### Scenario: Explicit filetype list restricts
- **WHEN** a pack declares `xml = { "xml" }` and an `.svg` file (filetype `svg`, mapped to the xml parser by nvim-treesitter) is opened
- **THEN** treesitter highlighting is not started in that buffer

#### Scenario: Explicit filetype list adds
- **WHEN** a pack declares `json = { "json", "jsonc" }` and a `.jsonc` file is opened
- **THEN** treesitter highlighting via the json parser is active

#### Scenario: Install without enabling
- **WHEN** a pack declares `latex = {}`
- **THEN** the latex parser is installed, and opening a `.tex` file does not start treesitter highlighting
