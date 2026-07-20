## MODIFIED Requirements

### Requirement: Multi-cursor editing
The configuration SHALL provide multi-cursor editing via `jake-stewart/multicursor.nvim`: `<C-n>` (normal and visual) selects the word under the cursor and adds the next matching occurrence per press, `<C-p>` adds the previous match, `q` skips the current match and jumps to the next, `<C-Up>`/`<C-Down>` add a cursor on the line above/below, `<C-Left>`/`<C-Right>` rotate the main cursor, `<leader>ma` adds cursors to all matches, visual-mode `<leader>m` helpers split/match/insert/append across the selection, `<leader>mx` deletes the current cursor, and `<Esc>` clears all cursors (or re-enables them when disabled). All regions are highlighted and edits are reflected on every cursor in real time.

#### Scenario: Add and skip occurrences
- **WHEN** the user presses `<C-n>` three times on a word and `q` once
- **THEN** three occurrences are selected (the skipped one excluded) and typing a change applies to all selected occurrences live

#### Scenario: Line cursors and clear
- **WHEN** the user presses `<C-Down>` twice to add cursors below and then `<Esc>`
- **THEN** cursors are added on the two lines below and `<Esc>` clears all extra cursors, returning to a single cursor
