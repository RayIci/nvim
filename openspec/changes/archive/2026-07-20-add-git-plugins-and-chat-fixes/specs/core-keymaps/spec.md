# core-keymaps Delta

## ADDED Requirements

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
