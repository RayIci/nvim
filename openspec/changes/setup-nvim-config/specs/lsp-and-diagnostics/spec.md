## ADDED Requirements

### Requirement: LSP servers are enabled natively
The configuration SHALL enable LSP servers exclusively through `vim.lsp.config()` and `vim.lsp.enable()`, using nvim-lspconfig only as the source of default server definitions. Completion capabilities from blink.cmp SHALL be applied globally via `vim.lsp.config('*', ...)`.

#### Scenario: Server attaches with capabilities
- **WHEN** a buffer whose filetype matches an enabled server is opened
- **THEN** the server attaches and its capabilities include blink.cmp's completion capabilities

### Requirement: LSP keymaps on attach
The configuration SHALL define buffer-local keymaps in an `LspAttach` autocmd for: go-to-definition, references, hover, rename, code action, and signature help, each with a `desc` for which-key.

#### Scenario: Keymaps available after attach
- **WHEN** an LSP client attaches to a buffer
- **THEN** `grd`/`grr`/`K`/`grn`/`gra` (or the chosen equivalents) work in that buffer and appear in which-key

### Requirement: Markdown-rendered hover and docs
The configuration SHALL render LSP hover and signature documentation as formatted markdown (treesitter-highlighted, syntax concealed) via noice.nvim.

#### Scenario: Hover rendering
- **WHEN** the user presses `K` on a symbol whose docs contain markdown (code fences, emphasis, lists)
- **THEN** the hover float shows highlighted code blocks and formatted text rather than raw markdown markup

### Requirement: Diagnostics are configured natively
The configuration SHALL configure `vim.diagnostic` with virtual text (or virtual lines for the current line), severity-distinguished signs, and keymaps to navigate diagnostics and open the float.

#### Scenario: Diagnostic display
- **WHEN** a server publishes diagnostics for a buffer
- **THEN** signs and virtual text render, and `]d`/`[d` jump between diagnostics
