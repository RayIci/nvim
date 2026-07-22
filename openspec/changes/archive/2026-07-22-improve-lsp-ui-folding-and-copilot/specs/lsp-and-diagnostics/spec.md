## ADDED Requirements

### Requirement: Multi-client code-action lightbulb
The configuration SHALL show a code-action lightbulb indicator when any non-ignored LSP client attached to the current buffer reports an available `textDocument/codeAction` at the cursor location. The indicator SHALL consider all active code-action-capable clients for the buffer rather than relying on a single client response.

#### Scenario: Action from secondary client
- **WHEN** multiple LSP clients are attached to a buffer and only one non-primary client reports a code action at the cursor
- **THEN** the lightbulb indicator is shown

#### Scenario: No actions from any client
- **WHEN** no attached code-action-capable LSP client reports an available action at the cursor
- **THEN** the lightbulb indicator is hidden

## MODIFIED Requirements

### Requirement: LSP keymaps on attach
The configuration SHALL define buffer-local keymaps in an `LspAttach` autocmd for lspsaga-backed go-to-definition, references, implementation, type-definition, and code action flows, plus native or existing providers for hover, rename, diagnostics, workspace folders, call hierarchy, inlay hints, and code lenses. Signature help SHALL NOT be mapped in insert mode on attach -- it is owned by blink.cmp's completion signature window and its `<C-k>` toggle -- leaving `<C-s>` free for saving. Additionally a `<leader>l` which-key group SHALL collect the LSP command tree: `<leader>la` opens lspsaga code actions, `<leader>lf` opens lspsaga finder, `<leader>lr` renames, `<leader>lk` opens signature help, `<leader>lo` opens the Trouble symbol outline, diagnostics subgroup `ld*` (line float, buffer picker, workspace picker, loclist, quickfix), workspace-folder subgroup `lw*` (add/remove/list), call-hierarchy subgroup `lh*` (incoming/outgoing), `<leader>li` toggles global inlay hints, and codelens subgroup `lc*` (run, refresh, toggle) -- with code lenses auto-refreshing for supporting servers while the global toggle is on (default on).

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
