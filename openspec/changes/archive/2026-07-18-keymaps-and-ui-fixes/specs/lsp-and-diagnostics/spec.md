# lsp-and-diagnostics Delta

## MODIFIED Requirements

### Requirement: LSP keymaps on attach
The configuration SHALL define buffer-local keymaps in an `LspAttach` autocmd for: go-to-definition, references, hover, rename, and code action, each with a `desc` for which-key. Signature help SHALL NOT be mapped in insert mode on attach — it is owned by blink.cmp's completion signature window and its `<C-k>` toggle — leaving `<C-s>` free for saving.

#### Scenario: Keymaps available after attach
- **WHEN** an LSP client attaches to a buffer
- **THEN** `grd`/`grr`/`K`/`grn`/`gra` (or the chosen equivalents) work in that buffer and appear in which-key

#### Scenario: Ctrl-S is not shadowed
- **WHEN** an LSP client attaches to a buffer and the user presses `<C-s>` in insert mode
- **THEN** the buffer is saved and no signature-help window opens

### Requirement: Markdown-rendered hover and docs
The configuration SHALL render LSP hover documentation as formatted markdown using Neovim 0.12's native treesitter-highlighted floating preview (no noice LSP overrides). LSP markdown content SHALL be normalized before rendering: backslash-escaped markdown characters and HTML entities emitted by servers such as pyright SHALL be unescaped/decoded via a hook on `vim.lsp.util.convert_input_to_markdown_lines`.

#### Scenario: Hover rendering
- **WHEN** the user opens hover on a symbol whose docs contain markdown (code fences, emphasis, lists)
- **THEN** the hover float shows highlighted code blocks and formatted text rather than raw markdown markup

#### Scenario: Escaped markdown normalized
- **WHEN** hover docs arrive from pyright containing `\\*\\*bold\\*\\*` and `&nbsp;` entities
- **THEN** the float shows bold text and plain spaces, not the escape sequences

## ADDED Requirements

### Requirement: Diagnostics insert-mode refresh toggle
The configuration SHALL default to refreshing diagnostics only after leaving insert mode (`update_in_insert = false`) and SHALL provide a toggle keymap that switches to live refresh while typing, with a notification of the new state. The toggle applies immediately without restart.

#### Scenario: Toggle to live refresh
- **WHEN** the user presses the diagnostics-refresh toggle keymap and then types code introducing an error in insert mode
- **THEN** the diagnostic appears while still in insert mode

#### Scenario: Default deferred refresh
- **WHEN** the toggle is in its default state and the user introduces an error in insert mode
- **THEN** the diagnostic appears only after returning to normal mode
