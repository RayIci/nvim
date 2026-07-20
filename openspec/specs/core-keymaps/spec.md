# core-keymaps Specification

## Purpose
TBD - created by syncing change keymaps-and-ui-fixes. Update Purpose after archive.

## Requirements

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

### Requirement: Pin-aware bulk buffer closing
The configuration SHALL provide bulk buffer-closing keymaps that respect bufferline pins and unsaved changes: `<leader>xa` SHALL delete all listed buffers that are neither pinned nor modified (creating a scratch buffer first so the editor survives, then focusing a remaining buffer if any), and `<leader>xA` SHALL delete all listed buffers except the current one, pinned ones, and modified ones.

#### Scenario: Close all keeps pinned and unsaved
- **WHEN** five buffers are open — one pinned, one modified — and the user presses `<leader>xa`
- **THEN** the three plain buffers are deleted while the pinned and modified buffers stay open

#### Scenario: Close others keeps current
- **WHEN** several buffers are open and the user presses `<leader>xA`
- **THEN** only the current buffer plus any pinned or modified buffers remain

### Requirement: Ctrl-C leaves insert mode as Escape
Insert-mode `<C-c>` SHALL behave as `<Esc>`, firing `InsertLeave` so mode-exit hooks (inline-suggestion cleanup, deferred diagnostics refresh) run.

#### Scenario: InsertLeave fires on Ctrl-C
- **WHEN** the user exits insert mode with `<C-c>` while a Copilot ghost-text suggestion is visible
- **THEN** InsertLeave autocmds fire and the ghost text is cleared, same as exiting with `<Esc>`

### Requirement: Save without formatting
`<C-a>` in normal and insert mode SHALL save the current buffer while bypassing format-on-save for that single write only; subsequent plain saves format again. Normal-mode number increment is shadowed (visual-mode `<C-a>` increment is unaffected).

#### Scenario: One-shot bypass
- **WHEN** format-on-save is enabled and the user saves a badly formatted buffer with `<C-a>`, then saves again with `<C-s>`
- **THEN** the first write leaves the content unformatted and the second write formats it

### Requirement: Shift+Enter stays in insert mode
Insert-mode `<S-CR>` SHALL insert a newline and remain in insert mode, identical to plain `<CR>` (modern terminals send Shift+Enter as a distinct key that would otherwise leave insert mode).

#### Scenario: Newline via Shift+Enter
- **WHEN** the user presses Shift+Enter while typing
- **THEN** the cursor moves to a new line and insert mode continues

### Requirement: jk and jj escape insert mode without lag
Typing `jk` or `jj` in insert mode SHALL return to normal mode via better-escape.nvim, with the first `j` rendered instantly (no pending-map delay) and removed when the sequence completes. The sequences SHALL apply to insert mode only — never terminal or cmdline mode — so interactive TUIs (lazygit) and terminal j/k navigation are unaffected.

#### Scenario: Escape via jk
- **WHEN** the user types text and then `jk` quickly in insert mode
- **THEN** the editor is in normal mode and the buffer contains only the typed text, with no leftover `j`

#### Scenario: Terminals untouched
- **WHEN** the user types `jj` or `jk` rapidly inside a lazygit or toggleterm terminal
- **THEN** the keys reach the terminal program unchanged

### Requirement: Tab management under leader-j
The configuration SHALL provide tab-management keymaps under a `<leader>j` which-key group: `<leader>j<Tab>`/`<leader>j<S-Tab>` next/previous tab, `<leader>jf`/`<leader>jl` first/last tab, `<leader>jc` create tab, `<leader>js` open the current buffer in a new tab, `<leader>jx` close tab (also `<leader>xj` in the close group), `<leader>jX` close all other tabs, `<leader>jm`/`<leader>jM` move tab right/left, `<leader>j0`/`<leader>j$` move tab to first/last position, and `<leader>j1`–`<leader>j9` jump to tab N. The built-in `gt`/`gT` (including count support) SHALL remain unmapped.

#### Scenario: Create and close tabs
- **WHEN** the user presses `<leader>jc` and then `<leader>jx`
- **THEN** a new tab opens and is then closed, returning to the previous tab

#### Scenario: Current buffer into a new tab
- **WHEN** the user presses `<leader>js` while editing a file
- **THEN** a new tab opens showing that same buffer

#### Scenario: Direct tab jump
- **WHEN** three tabs exist and the user presses `<leader>j2`
- **THEN** tab 2 becomes the current tab
