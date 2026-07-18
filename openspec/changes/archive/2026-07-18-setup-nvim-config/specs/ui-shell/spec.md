## ADDED Requirements

### Requirement: Theme switcher with persistence
The configuration SHALL install catppuccin, tokyonight, kanagawa, gruvbox, rose-pine, nightfox, onedark, everforest, and nord, and provide a themery.nvim picker (`<leader>ut`) whose selection persists across restarts. Themery's self-modifying block SHALL be confined to a dedicated small file.

#### Scenario: Theme persists
- **WHEN** the user selects kanagawa in the themery picker and restarts Neovim
- **THEN** kanagawa is the active colorscheme after restart

### Requirement: Telescope fuzzy finding
The configuration SHALL provide telescope.nvim with the fzf-native sorter and keymaps for: find files, live grep, buffers, help tags, recent files, and resume, under a `<leader>f` which-key group.

#### Scenario: Live grep
- **WHEN** the user presses the live-grep keymap and types a pattern
- **THEN** matching lines across the project appear via ripgrep and selecting one jumps to it

### Requirement: Which-key discoverability
The configuration SHALL load which-key.nvim with named groups for all leader prefixes (find, git, debug, code, ui, trouble) so pressing `<leader>` shows a labeled popup. All plugin keymaps SHALL carry `desc`.

#### Scenario: Leader popup
- **WHEN** the user presses `<leader>` and waits
- **THEN** a popup lists the named groups and bindings with human-readable descriptions

### Requirement: Shell UI plugins
The configuration SHALL include: neo-tree.nvim (file explorer toggle on `<leader>e`), lualine.nvim (mode, branch, diff, diagnostics, filetype), trouble.nvim (diagnostics/quickfix panels under `<leader>x`), todo-comments.nvim (TODO/FIXME highlighting + telescope picker), and indent-blankline.nvim (indent guides).

#### Scenario: Explorer toggle
- **WHEN** the user presses `<leader>e`
- **THEN** neo-tree opens showing the project tree, and pressing it again closes it

#### Scenario: Diagnostics panel
- **WHEN** the user opens the trouble diagnostics view with diagnostics present
- **THEN** a structured list of project diagnostics is shown and selecting an entry jumps to its location

### Requirement: Bufferline with pinnable buffers
The configuration SHALL show open buffers in a bufferline.nvim top bar with diagnostics indicators, close buttons, and a pin toggle keymap; pinned buffers SHALL sort before unpinned ones.

#### Scenario: Pin a buffer
- **WHEN** the user presses the pin keymap on a buffer
- **THEN** the buffer shows a pin indicator and moves to the pinned section of the bufferline

### Requirement: Plugin-free session restore with pins
The configuration SHALL provide session save/restore through a custom workspace-state module using native `:mksession` — no session plugin. Sessions are keyed per project (cwd), auto-saved on exit, and restored via an explicit command/keymap. Restoring SHALL reopen the previous buffers and window layout, re-apply bufferline pinned state, and trigger breakpoint restoration.

#### Scenario: Session round-trip
- **WHEN** the user has several buffers open (two pinned), quits Neovim, reopens it in the same directory, and runs the restore command
- **THEN** the same buffers and layout return and the two buffers are pinned again

### Requirement: Noice cmdline and message UI
The configuration SHALL use noice.nvim for the command-line popup and message routing, consistent with its role rendering LSP docs.

#### Scenario: Cmdline popup
- **WHEN** the user presses `:`
- **THEN** a centered cmdline popup appears instead of the bottom-row cmdline

### Requirement: Undotree access
The configuration SHALL expose Neovim 0.12's built-in `:Undotree` via a keymap.

#### Scenario: Open undotree
- **WHEN** the user presses the undotree keymap
- **THEN** the built-in undo tree view opens for the current buffer
