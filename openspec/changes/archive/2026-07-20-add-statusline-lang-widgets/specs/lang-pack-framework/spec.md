## MODIFIED Requirements

### Requirement: One file registers a complete language
The configuration SHALL provide a loader (`lua/langs/init.lua`) that automatically discovers every `lua/langs/<language>.lua` file and wires its declared `treesitter`, `lsp`, `formatters`, `linters`, `dap`, and `mason` fields into nvim-treesitter, `vim.lsp.config`/`vim.lsp.enable`, conform.nvim, nvim-lint, nvim-dap, and mason-tool-installer respectively. A pack MAY additionally declare:
- `packs` — a list of vim.pack plugin specs (with optional per-entry `build` hooks) that the loader installs via a single `vim.pack.add()` call, registering build hooks on `PackChanged` before installation;
- `test` — a factory function returning one or more neotest adapters, forwarded to the neotest subsystem's `apply()`;
- `completion` — blink.cmp source contributions (`providers`, `per_filetype`, `default`) merged into blink's sources before its deferred setup;
- `statusline` — a list of statusline widget specs (each a `render` function returning a string, plus optional `cond`, `icon`, and `color`) that the loader merges and forwards to the lualine subsystem's `apply()`, which surfaces them through a dynamic bridge component;
- `setup` — a function the loader runs after all subsystem wiring so packs can integrate with fully-initialized modules (e.g. registering terminal hooks, keymaps, and user commands for plugins declared in `packs`).

Adding a language MUST require creating exactly one file with no edits to core config.

#### Scenario: Drop-in language file
- **WHEN** a new file `lua/langs/go.lua` returning the spec table is created and Neovim restarts
- **THEN** the Go LSP attaches to Go buffers, its formatter/linter run for the `go` filetype, its mason tools install, and its treesitter parser is available — with no other file modified

#### Scenario: All fields optional
- **WHEN** a language file declares only `lsp` and `mason` (no dap, linters, formatters, packs, test, completion, or statusline)
- **THEN** the loader wires the declared fields and skips the missing ones without error

#### Scenario: Pack setup runs after wiring
- **WHEN** a pack declares a `setup` function that registers a terminal on_create hook
- **THEN** the function runs during startup after subsystems are wired, and the hook fires when a terminal is later created

#### Scenario: Pack-declared plugin with build hook
- **WHEN** a pack declares `packs = { { src = "iamcco/markdown-preview.nvim", build = <fn> } }` and the plugin is not yet installed
- **THEN** vim.pack installs it during startup and the build hook runs on the install event

#### Scenario: Pack-declared completion source
- **WHEN** a pack declares a `completion` table with a provider and a `per_filetype` entry
- **THEN** blink.cmp offers that source in the declared filetypes after startup

#### Scenario: Pack-declared statusline widget
- **WHEN** a pack declares `statusline = { { render = fn, cond = fn, icon = "🐍" } }`
- **THEN** the loader forwards it to lualine's `apply()`, and the widget's `render()` output appears in the statusline whenever its `cond` is satisfied and the string is non-empty
