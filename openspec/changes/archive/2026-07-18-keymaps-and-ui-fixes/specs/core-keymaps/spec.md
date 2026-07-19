# core-keymaps Delta

## ADDED Requirements

### Requirement: Save with Ctrl-S
The configuration SHALL save the current buffer with `<C-s>` in both normal and insert mode; from insert mode the mapping SHALL return to normal mode after saving. No other action SHALL be bound to `<C-s>` in these modes.

#### Scenario: Save from insert mode
- **WHEN** the user presses `<C-s>` while in insert mode with unsaved changes
- **THEN** the buffer is written and the editor returns to normal mode

### Requirement: Clear search highlight with Ctrl-X
The configuration SHALL clear the active search highlight with `<C-x>` in normal mode, in addition to the existing `<Esc>` mapping.

#### Scenario: Dismiss highlight after search
- **WHEN** the user has active `/`-search highlights and presses `<C-x>` in normal mode
- **THEN** all search highlights are cleared

### Requirement: Buffer cycling with Tab
The configuration SHALL cycle to the next buffer with `<Tab>` and the previous buffer with `<S-Tab>` in normal mode, following bufferline's visual order.

#### Scenario: Cycle through bufferline
- **WHEN** three buffers are open and the user presses `<Tab>` twice
- **THEN** the active buffer advances two positions in the bufferline order

### Requirement: Layout-preserving buffer close
The configuration SHALL close the current buffer with `<leader>xw` without closing its window: every window showing the buffer SHALL switch to another listed buffer (or an empty one) before the buffer is deleted, and unsaved changes SHALL block deletion with a message rather than being discarded.

#### Scenario: Close buffer in a split
- **WHEN** two vertical splits show different buffers and the user presses `<leader>xw` in one
- **THEN** that buffer is deleted, the split layout remains, and the window shows another listed buffer

#### Scenario: Unsaved changes protected
- **WHEN** the user presses `<leader>xw` on a modified buffer
- **THEN** the buffer is not deleted and a message indicates unsaved changes

### Requirement: Seamless tmux pane navigation
The configuration SHALL navigate across Neovim splits and tmux panes with the same `<C-h>`/`<C-j>`/`<C-k>`/`<C-l>` keys via vim-tmux-navigator: at an edge split inside tmux the focus SHALL move to the adjacent tmux pane, and outside tmux the keys SHALL fall back to plain window navigation.

#### Scenario: Cross into tmux pane
- **WHEN** Neovim runs in a tmux pane with another pane to the right and the cursor is in the rightmost split
- **THEN** pressing `<C-l>` focuses the tmux pane to the right

#### Scenario: Fallback outside tmux
- **WHEN** Neovim runs outside tmux with two vertical splits
- **THEN** `<C-h>`/`<C-l>` move between the splits as before
