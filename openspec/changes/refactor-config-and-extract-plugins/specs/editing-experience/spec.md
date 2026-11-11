# Spec Delta

## MODIFIED Requirements

### Requirement: Multi-cursor line, rotation and session keys
`<M-Up>`/`<M-Down>` SHALL add a cursor on the line above/below, `<M-Left>`/`<M-Right>` rotate the main cursor, visual-mode `<leader>m` helpers split/match/insert/append across the selection, and `<Esc>` clears all cursors (or re-enables them when disabled). The `q` and `<Esc>` bindings live in a buffer-local keymap layer active only while cursors exist, so they take precedence over global mappings (e.g. `<Esc>` → nohlsearch) during a session and revert afterwards.

#### Scenario: Line cursors and clear
- **WHEN** the user presses `<M-Down>` twice to add cursors below and then `<Esc>`
- **THEN** cursors are added on the two lines below and `<Esc>` clears all extra cursors, returning to a single cursor

#### Scenario: Line cursors from normal mode
- **WHEN** the user presses `<M-Up>` in normal mode with no cursors active
- **THEN** a cursor is added on the line above, and the window size does not change

#### Scenario: Ctrl-arrows no longer add cursors
- **WHEN** the user presses `<C-Down>` in normal or visual mode
- **THEN** no cursor is added
