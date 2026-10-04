# Spec Delta

## ADDED Requirements

### Requirement: Oil floating explorer
The configuration SHALL provide oil.nvim as a secondary file explorer that coexists with neo-tree. Pressing `<leader>E` SHALL open oil in a floating window, listing the directory of the current buffer's file, or the current working directory when the buffer has no file on disk. Oil MUST NOT take over directory buffers: opening a directory (`nvim .`, `:e <dir>`) SHALL keep its current behavior, and neo-tree SHALL keep `<leader>e`. Inside an oil buffer, `<BS>` in normal mode SHALL go to the parent directory, like `-`, while insert-mode `<BS>` keeps deleting characters. In an oil buffer, `g|` SHALL open the entry under the cursor in a vertical (side-by-side) split, `g-` in a horizontal (stacked) split, and `gR` SHALL refresh the listing. Oil MUST NOT shadow `<C-s>` (save) or `<C-h>`/`<C-l>` (tmux-navigator), so those global mappings keep working inside oil. Oil windows SHALL show no winbar breadcrumb, and oil buffers SHALL NOT appear in the bufferline or be restored by sessions.

#### Scenario: Float on the current file's directory
- **WHEN** the user is editing `lua/plugins/oil.lua` and presses `<leader>E`
- **THEN** a floating oil window opens listing the `lua/plugins/` directory

#### Scenario: Backspace goes up a directory
- **WHEN** the oil float lists `lua/plugins/` and the user presses `<BS>` in normal mode
- **THEN** the float lists `lua/`

#### Scenario: Split keys mirror tmux
- **WHEN** the cursor is on a file in the oil float and the user presses `g|`
- **THEN** the float closes and the file opens in a side-by-side split; with `g-` it opens in a stacked split

#### Scenario: Global Ctrl maps work inside oil
- **WHEN** focus is in an oil buffer and the user presses `<C-s>`, `<C-h>` or `<C-l>`
- **THEN** the global save or tmux-navigator mapping runs, not an oil action

#### Scenario: Fallback to cwd
- **WHEN** the current buffer has no file on disk (an empty start buffer or a scratch buffer) and the user presses `<leader>E`
- **THEN** the floating oil window lists the current working directory

#### Scenario: Filesystem edits apply on save
- **WHEN** the user renames an entry in the oil float and writes the buffer, confirming the action prompt
- **THEN** the file is renamed on disk

#### Scenario: Neo-tree keeps directory buffers
- **WHEN** the user starts Neovim with `nvim .`
- **THEN** the directory opens the same way it did before oil was added, and no oil buffer is created

#### Scenario: Neo-tree toggle unchanged
- **WHEN** the user presses `<leader>e`
- **THEN** neo-tree toggles as before, focused on the current file

#### Scenario: Oil leaves no trace in tabs or sessions
- **WHEN** the user opens and closes the oil float, then quits and the session is restored
- **THEN** no `oil://` buffer appears in the bufferline before or after the restore

#### Scenario: Revisited oil buffers stay hidden
- **WHEN** the user toggles oil's trash view twice (`g\` then `g\`) or navigates back into a directory already visited
- **THEN** no `oil://` or `oil-trash://` buffer appears in the bufferline, during or after the oil session

#### Scenario: Oil open at quit or :restart
- **WHEN** oil is showing (in the float or a normal window) and the user runs `:qa` and reopens, or runs `:restart`
- **THEN** the restored session has no `oil://` buffer, and the window that showed oil shows its previous file
