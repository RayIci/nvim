# ui-shell Delta

## MODIFIED Requirements

### Requirement: Telescope fuzzy finding
The configuration SHALL provide telescope.nvim with the fzf-native sorter and keymaps for: find files, live grep, buffers, help tags, recent files, and resume, under a `<leader>f` which-key group. `<leader><leader>` SHALL open the find-files picker and `<leader>ff` SHALL resume the last-used picker with its previous query and results.

#### Scenario: Live grep
- **WHEN** the user presses the live-grep keymap and types a pattern
- **THEN** matching lines across the project appear via ripgrep and selecting one jumps to it

#### Scenario: Quick find files
- **WHEN** the user presses `<leader><leader>`
- **THEN** the find-files picker opens

#### Scenario: Resume last picker
- **WHEN** the user runs a live-grep search, closes it, and presses `<leader>ff`
- **THEN** the live-grep picker reopens with the previous query and results

### Requirement: Noice cmdline and message UI
The configuration SHALL use noice.nvim for the command-line popup and message routing only: its LSP overrides (`convert_input_to_markdown_lines`, `stylize_markdown`), hover handler, and signature handler SHALL be disabled so LSP documentation rendering is owned by native Neovim and blink.cmp.

#### Scenario: Cmdline popup
- **WHEN** the user presses `:`
- **THEN** a centered cmdline popup appears instead of the bottom-row cmdline

#### Scenario: No noice LSP interference
- **WHEN** an LSP hover or signature window is opened
- **THEN** noice does not render or override it

## ADDED Requirements

### Requirement: Neo-tree smart file opening
The neo-tree window SHALL be 45 columns wide, and pressing `w` or `<cr>` on a file SHALL open it via nvim-window-picker: with at most one eligible target window the file opens directly; with multiple eligible windows a picker prompts for the destination, excluding neo-tree, notification, terminal, and quickfix windows. Pressing `w` or `<cr>` on a directory SHALL toggle it.

#### Scenario: Open with single window
- **WHEN** one editing window exists and the user presses `w` on a file in neo-tree
- **THEN** the file opens in that window without any picker prompt

#### Scenario: Open with multiple windows
- **WHEN** two editing windows exist and the user presses `w` on a file in neo-tree
- **THEN** a window-picker overlay appears and the file opens in the chosen window

### Requirement: Telescope-backed vim.ui.select
The configuration SHALL register telescope-ui-select as the `vim.ui.select` provider so all selection prompts (DAP configuration chooser, code actions) render as a telescope picker.

#### Scenario: DAP configuration chooser
- **WHEN** the user starts `dap.continue()` with multiple debug configurations available
- **THEN** a telescope picker lists the configurations by name and selecting one starts that session

#### Scenario: Code action selection
- **WHEN** the user triggers a code action with multiple actions available
- **THEN** the actions appear in a telescope picker
