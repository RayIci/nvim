# Spec Delta

## ADDED Requirements

### Requirement: LSP navigation keymaps on attach
On `LspAttach` the configuration SHALL define buffer-local keymaps for definition (`gd`), declaration (`gD`), references (`grr`), implementation (`gri`), type definition (`grt`), rename (`grn`), code action (`gra`), document symbols (`gO`) and hover (`H`). Navigation with a single target SHALL jump directly; with several targets it SHALL open a picker with a preview.

#### Scenario: Single definition jumps
- **WHEN** the user presses `gd` on a symbol with exactly one definition
- **THEN** the cursor moves to that definition without any picker

#### Scenario: References in a picker
- **WHEN** the user presses `grr` on a symbol used in several files
- **THEN** a picker lists every reference with a preview, and selecting one jumps to it

### Requirement: Signature help stays with completion
Signature help SHALL NOT be mapped in insert mode on attach: it is owned by blink.cmp's completion signature window and its `<C-k>` toggle, which leaves `<C-s>` free for saving.

#### Scenario: Ctrl-S is not shadowed
- **WHEN** an LSP client attaches to a buffer and the user presses `<C-s>` in insert mode
- **THEN** the buffer is saved and no signature-help window opens

## MODIFIED Requirements

### Requirement: LSP leader command tree
A `<leader>l` which-key group SHALL collect the LSP command tree: `<leader>la` code actions, `<leader>lf` a finder listing references and implementations of the symbol together, `<leader>lr` rename, `<leader>lk` signature help, `<leader>lo` the Trouble symbol outline, diagnostics subgroup `ld*` (line float, buffer picker, workspace picker, loclist, quickfix), workspace-folder subgroup `lw*` (add/remove/list), call-hierarchy subgroup `lh*` (incoming/outgoing pickers), and `<leader>li` toggling global inlay hints.

#### Scenario: Keymaps available after attach
- **WHEN** an LSP client attaches to a buffer
- **THEN** `gd`, `grr`, `gri`, `grt`, `gra`, `<leader>la`, and `<leader>lf` work in that buffer and the `<leader>l` tree appears in which-key

#### Scenario: Combined finder
- **WHEN** the user presses `<leader>lf` on an interface method that is referenced twice and implemented once
- **THEN** one picker lists the two references and the implementation, each marked with its kind

## REMOVED Requirements

### Requirement: LSP keymaps on attach
**Reason**: It assigned navigation and code actions to lspsaga, which is removed. The keymaps are restated, with the same keys, as "LSP navigation keymaps on attach" and "Signature help stays with completion".
**Migration**: None. The same keys work with native LSP and the snacks picker.
