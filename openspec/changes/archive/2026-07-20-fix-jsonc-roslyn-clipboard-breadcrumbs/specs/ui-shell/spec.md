## ADDED Requirements

### Requirement: Winbar symbol breadcrumbs
The configuration SHALL display a VSCode-style breadcrumb in the winbar showing the path of the symbol (namespace/class/function) enclosing the cursor, backed by barbecue.nvim and nvim-navic. The breadcrumb SHALL update automatically as the cursor moves and SHALL be shown only in windows displaying editable code buffers — it MUST NOT appear in neo-tree, terminal/toggleterm, or other plugin panels and floating windows.

#### Scenario: Breadcrumb follows the cursor
- **WHEN** the cursor is inside a function within a code buffer with an LSP that provides document symbols
- **THEN** the winbar shows the enclosing symbol path (e.g. `file › Class › Method`)
- **AND** moving the cursor into a different symbol updates the breadcrumb

#### Scenario: No breadcrumb on non-code windows
- **WHEN** focus is in the neo-tree explorer, a terminal, or another plugin panel
- **THEN** no breadcrumb winbar is shown for that window
