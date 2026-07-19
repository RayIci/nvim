# lang-pack-framework Delta

## MODIFIED Requirements

### Requirement: One file registers a complete language
The configuration SHALL provide a loader (`lua/langs/init.lua`) that automatically discovers every `lua/langs/<language>.lua` file and wires its declared `treesitter`, `lsp`, `formatters`, `linters`, `dap`, and `mason` fields into nvim-treesitter, `vim.lsp.config`/`vim.lsp.enable`, conform.nvim, nvim-lint, nvim-dap, and mason-tool-installer respectively. A pack MAY additionally declare a `setup` function, which the loader runs after all subsystem wiring so packs can integrate with fully-initialized modules (e.g. registering terminal hooks). Adding a language MUST require creating exactly one file with no edits to core config.

#### Scenario: Drop-in language file
- **WHEN** a new file `lua/langs/go.lua` returning the spec table is created and Neovim restarts
- **THEN** the Go LSP attaches to Go buffers, its formatter/linter run for the `go` filetype, its mason tools install, and its treesitter parser is available — with no other file modified

#### Scenario: All fields optional
- **WHEN** a language file declares only `lsp` and `mason` (no dap, linters, or formatters)
- **THEN** the loader wires the declared fields and skips the missing ones without error

#### Scenario: Pack setup runs after wiring
- **WHEN** a pack declares a `setup` function that registers a terminal on_create hook
- **THEN** the function runs during startup after subsystems are wired, and the hook fires when a terminal is later created
