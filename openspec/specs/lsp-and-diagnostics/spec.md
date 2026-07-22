# lsp-and-diagnostics Specification

## Purpose
TBD - created by syncing change setup-nvim-config. Update Purpose after archive.

## Requirements

### Requirement: LSP servers are enabled natively
The configuration SHALL enable LSP servers exclusively through `vim.lsp.config()` and `vim.lsp.enable()`, using nvim-lspconfig only as the source of default server definitions. Completion capabilities from blink.cmp SHALL be applied globally via `vim.lsp.config('*', ...)`.

#### Scenario: Server attaches with capabilities
- **WHEN** a buffer whose filetype matches an enabled server is opened
- **THEN** the server attaches and its capabilities include blink.cmp's completion capabilities

### Requirement: LSP keymaps on attach
The configuration SHALL define buffer-local keymaps in an `LspAttach` autocmd for lspsaga-backed go-to-definition, references, implementation, type-definition, and code action flows, plus native or existing providers for hover, rename, diagnostics, workspace folders, call hierarchy, inlay hints, and code lenses. Signature help SHALL NOT be mapped in insert mode on attach — it is owned by blink.cmp's completion signature window and its `<C-k>` toggle — leaving `<C-s>` free for saving. Additionally a `<leader>l` which-key group SHALL collect the LSP command tree: `<leader>la` opens lspsaga code actions, `<leader>lf` opens lspsaga finder, `<leader>lr` renames, `<leader>lk` opens signature help, `<leader>lo` opens the Trouble symbol outline, diagnostics subgroup `ld*` (line float, buffer picker, workspace picker, loclist, quickfix), workspace-folder subgroup `lw*` (add/remove/list), call-hierarchy subgroup `lh*` (incoming/outgoing), `<leader>li` toggles global inlay hints, and codelens subgroup `lc*` (run, refresh, toggle) — with code lenses auto-refreshing for supporting servers while the global toggle is on (default on).

#### Scenario: Keymaps available after attach
- **WHEN** an LSP client attaches to a buffer
- **THEN** `gd`, `grr`, `gri`, `grt`, `gra`, `<leader>la`, and `<leader>lf` work in that buffer and the `<leader>l` tree appears in which-key

#### Scenario: Ctrl-S is not shadowed
- **WHEN** an LSP client attaches to a buffer and the user presses `<C-s>` in insert mode
- **THEN** the buffer is saved and no signature-help window opens

#### Scenario: Codelens lifecycle
- **WHEN** a server supporting code lenses attaches and the user toggles lenses off with `<leader>lct`
- **THEN** rendered lenses are cleared and no refresh runs until toggled back on

#### Scenario: Lspsaga scope stays narrow
- **WHEN** the LSP keymaps are installed
- **THEN** lspsaga is used for the selected navigation, finder, and code-action flows only
- **AND** breadcrumbs, outline, diagnostics, hover, rename, terminal, and lightbulb remain owned by their existing providers unless separately changed

### Requirement: Multi-client code-action lightbulb
The configuration SHALL show a code-action lightbulb indicator when any non-ignored LSP client attached to the current buffer reports an available `textDocument/codeAction` at the cursor location. The indicator SHALL consider all active code-action-capable clients for the buffer rather than relying on a single client response.

#### Scenario: Action from secondary client
- **WHEN** multiple LSP clients are attached to a buffer and only one non-primary client reports a code action at the cursor
- **THEN** the lightbulb indicator is shown

#### Scenario: No actions from any client
- **WHEN** no attached code-action-capable LSP client reports an available action at the cursor
- **THEN** the lightbulb indicator is hidden

### Requirement: Markdown-rendered hover and docs
The configuration SHALL render LSP hover documentation as formatted markdown using Neovim 0.12's native treesitter-highlighted floating preview (no noice LSP overrides). LSP markdown content SHALL be normalized before rendering: backslash-escaped markdown characters and HTML entities emitted by servers such as pyright SHALL be unescaped/decoded via a hook on `vim.lsp.util.convert_input_to_markdown_lines`.

#### Scenario: Hover rendering
- **WHEN** the user opens hover on a symbol whose docs contain markdown (code fences, emphasis, lists)
- **THEN** the hover float shows highlighted code blocks and formatted text rather than raw markdown markup

#### Scenario: Escaped markdown normalized
- **WHEN** hover docs arrive from pyright containing `\\*\\*bold\\*\\*` and `&nbsp;` entities
- **THEN** the float shows bold text and plain spaces, not the escape sequences

### Requirement: Diagnostics are configured natively
The configuration SHALL configure `vim.diagnostic` with virtual text (or virtual lines for the current line), severity-distinguished signs, and keymaps to navigate diagnostics and open the float.

#### Scenario: Diagnostic display
- **WHEN** a server publishes diagnostics for a buffer
- **THEN** signs and virtual text render, and `]d`/`[d` jump between diagnostics

### Requirement: Diagnostics insert-mode refresh toggle
By default diagnostics SHALL appear on buffer open, on save, and after leaving insert mode: linters run on `BufReadPost`/`BufWritePost`/`InsertLeave` and diagnostic display defers insert-mode updates (`update_in_insert = false`). A toggle keymap SHALL switch to live refresh — diagnostic display updates in insert mode AND linters run debounced on every text change — with the chosen state persisted across restarts through the prefs module and applied immediately without restart.

#### Scenario: Diagnostics on open
- **WHEN** a file with existing lint findings is opened
- **THEN** its diagnostics appear without requiring a save

#### Scenario: Toggle to live refresh
- **WHEN** the user enables live diagnostics with the toggle keymap and types code introducing a lint error
- **THEN** the diagnostic appears while still typing, without leaving insert mode or saving

#### Scenario: Toggle persists
- **WHEN** the user enables live diagnostics and restarts Neovim
- **THEN** diagnostics still refresh while typing until toggled back

#### Scenario: Default deferred refresh
- **WHEN** the toggle is off and the user introduces an error in insert mode
- **THEN** the diagnostic appears after returning to normal mode
