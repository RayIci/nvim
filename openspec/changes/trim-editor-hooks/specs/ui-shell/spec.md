# Spec Delta

## ADDED Requirements

### Requirement: Statusline symbol breadcrumbs
The statusline SHALL show the path of the symbol (namespace/class/function) enclosing the cursor in the current code buffer, from its language server's document symbols, updating as the cursor moves. Buffers without such a server, explorer windows, terminals and plugin panels SHALL show no breadcrumb. `<leader>ub` SHALL toggle breadcrumbs, persisted across restarts. No window SHALL get a breadcrumb winbar.

#### Scenario: Breadcrumb follows the cursor
- **WHEN** the cursor is inside a method of a class in a buffer whose server provides document symbols
- **THEN** the statusline shows the enclosing path (e.g. `Class › Method`), and moving into another symbol updates it

#### Scenario: No breadcrumb on non-code windows
- **WHEN** focus is in the explorer, a terminal, or another plugin panel
- **THEN** the statusline shows no breadcrumb and no window has a winbar

#### Scenario: Toggle persists
- **WHEN** the user presses `<leader>ub` and restarts Neovim
- **THEN** no breadcrumb is shown until `<leader>ub` is pressed again

### Requirement: TODO comment navigation
`]t` and `[t` SHALL jump to the next and previous TODO-style comment (TODO, FIXME, HACK, NOTE and the other todo-comments keywords) in the current buffer.

#### Scenario: Jump to the next TODO
- **WHEN** a buffer has `-- TODO: a` on line 5 and `-- FIXME: b` on line 20 and the cursor is on line 6
- **THEN** `]t` moves the cursor to line 20 and `[t` back to line 5

## MODIFIED Requirements

### Requirement: Buffer tooling indicators in the statusline
The statusline SHALL show icon-distinguished, buffer-scoped indicators for the active LSP clients, conform formatters, and nvim-lint linters of the current buffer. Each indicator SHALL read global state keyed by the current buffer (`vim.lsp.get_clients`, `conform.list_formatters`, `lint.linters_by_ft`), carry its own icon and color so the three are visually distinguishable, and render nothing when its list is empty.

#### Scenario: Indicators reflect the current buffer
- **WHEN** a Python buffer is open with basedpyright + ruff attached, ruff configured as formatter, and mypy as linter
- **THEN** the statusline shows an LSP indicator listing the clients, a formatter indicator listing the formatters, and a linter indicator listing mypy, each with its distinguishing icon

#### Scenario: Empty indicators hide
- **WHEN** a buffer has no linters configured for its filetype
- **THEN** the linter indicator renders nothing (no empty icon or label)

## REMOVED Requirements

### Requirement: Winbar symbol breadcrumbs
**Reason**: The breadcrumb moves into the statusline. A per-window winbar redraw on every cursor move, plus the workaround that cleared it from terminals and panels, is no longer needed.
**Migration**: See "Statusline symbol breadcrumbs". `<leader>ub` toggles it.
