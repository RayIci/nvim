# Spec Delta

## ADDED Requirements

### Requirement: Sidebar file explorer
`<leader>e` SHALL toggle a 45-column file explorer sidebar on the left showing the project tree, following the current file and marking git status and diagnostics. Opening a directory (`nvim .`, `:e <dir>`) SHALL show that directory in the explorer. Closing the last editing window SHALL quit Neovim even while the explorer is open.

#### Scenario: Explorer toggle
- **WHEN** the user presses `<leader>e`
- **THEN** the explorer opens showing the project tree with the current file revealed, and pressing it again closes it

#### Scenario: Last window quits
- **WHEN** the explorer and one file window are open and the user runs `:q` in the file window
- **THEN** Neovim exits rather than leaving the explorer alone on screen

### Requirement: Explorer file opening
Pressing `w` or `<cr>` on a file in the explorer SHALL open it directly when at most one eligible editing window exists, and otherwise SHALL ask which window to use, offering only editing windows (never the explorer, notifications, terminals or quickfix). Pressing `w` or `<cr>` on a directory SHALL expand or collapse it.

#### Scenario: Open with single window
- **WHEN** one editing window exists and the user presses `w` on a file in the explorer
- **THEN** the file opens in that window without any prompt

#### Scenario: Open with multiple windows
- **WHEN** two editing windows exist and the user presses `w` on a file in the explorer
- **THEN** each editing window is labelled and the file opens in the chosen one

### Requirement: Explorer hide lists and advanced yank
The explorer SHALL hide by default `.git`, `.github`, cache dirs (`.mypy_cache`, `.pytest_cache`, `.ruff_cache`), `bin`/`obj`, `node_modules`, `.next`, venv directories and `*.egg-info`, with `H` showing or hiding them. `__pycache__` and conform's `.conform.*` files SHALL never be shown. Other dotfiles and git-ignored files SHALL stay visible. `Y` SHALL open the chooser that copies the node's filename, stem, absolute path, cwd-relative path, home-relative path or extension to the clipboard.

#### Scenario: Advanced yank
- **WHEN** the user presses `Y` on a file in the explorer and picks "Path relative to CWD"
- **THEN** that relative path lands in the system clipboard

#### Scenario: Noise hidden
- **WHEN** a project contains `__pycache__` and `node_modules` directories
- **THEN** `__pycache__` never appears and `node_modules` is hidden until the user presses `H`

#### Scenario: Formatter temp files stay hidden
- **WHEN** the user saves a Markdown file and conform formats it through a temporary `.conform.*` file in the same directory
- **THEN** the temporary file never appears in the explorer, not even briefly

### Requirement: Global keys inside the explorer
Inside the explorer, `<C-h>`/`<C-j>`/`<C-k>`/`<C-l>` SHALL run the global tmux-aware window navigation, `<C-s>` the global save mapping and `<C-t>` the global terminal toggle, rather than explorer list actions.

#### Scenario: Navigate out of the explorer
- **WHEN** focus is in the explorer and the user presses `<C-l>`
- **THEN** focus moves to the window on the right, not to a list action

### Requirement: Explorer reflects external changes
When files change outside Neovim (another terminal, an AI agent), the explorer's git marks SHALL update when Neovim regains focus, when the user leaves a terminal, and when agentdiff reports new agent changes, including files inside collapsed folders. The editor SHALL NOT run `git status` in response to entering buffers or idling.

#### Scenario: Agent edit in a collapsed folder
- **WHEN** the explorer shows `src/` collapsed and an agent in another tmux pane modifies `src/a.lua`
- **THEN** `src/` shows a modified git mark once agentdiff reports the change or Neovim regains focus

#### Scenario: No git polling while editing
- **WHEN** the user switches between buffers and rests the cursor without any file changing on disk
- **THEN** no `git status` process is started by the editor

### Requirement: Automatic session restore with pins and explorer
The configuration SHALL provide automatic session management through auto-session: sessions are keyed per project (cwd), saved automatically on exit, and restored automatically when Neovim starts with no file arguments in a directory that has a saved session. Session keymaps SHALL live under a `<leader>q` which-key group (save, restore, search picker, delete, toggle auto-save). Breakpoint restoration stays with the workspace module and SHALL still fire for session-restored buffers.

#### Scenario: Automatic session round-trip
- **WHEN** the user has several buffers open (two pinned), quits Neovim, and reopens it in the same directory with no file arguments
- **THEN** the same buffers and window layout return automatically and the two buffers are pinned again

#### Scenario: No restore with file arguments
- **WHEN** the user opens Neovim with an explicit file argument (`nvim foo.py`)
- **THEN** no session is restored and the requested file opens normally

#### Scenario: Breakpoints after auto-restore
- **WHEN** a session restore brings back a file that has persisted breakpoints
- **THEN** those breakpoints are registered with nvim-dap

#### Scenario: Explorer state restored with the session
- **WHEN** the user has the explorer open with several folders expanded, quits, and the session is restored (automatically or manually)
- **THEN** the explorer reopens with the same folders expanded

#### Scenario: Closed explorer stays closed
- **WHEN** the explorer was closed at exit and the session is restored
- **THEN** the explorer does not open

#### Scenario: Explorer state survives :restart
- **WHEN** the user expands folders or opens/closes the explorer and the process ends without exit hooks (`:restart`, crash, kill)
- **THEN** the latest explorer state was already persisted when it changed and is restored next time, with no empty leftover explorer window

#### Scenario: Unopened explorer keeps its memory
- **WHEN** a session ends in which the explorer was never opened
- **THEN** the previously saved expanded-folders list is preserved, not wiped

#### Scenario: State saved by the previous explorer carries over
- **WHEN** a project has explorer state saved by the previous neo-tree-based configuration and Neovim starts there for the first time after this change
- **THEN** the explorer opens (or stays closed) and expands folders as that saved state says

### Requirement: Oil floating explorer alongside the sidebar
The configuration SHALL provide oil.nvim as a secondary file explorer next to the sidebar explorer. Pressing `<leader>E` SHALL open oil in a floating window, listing the directory of the current buffer's file, or the current working directory when the buffer has no file on disk. Oil MUST NOT take over directory buffers, which stay with the sidebar explorer, and the sidebar SHALL keep `<leader>e`.

#### Scenario: Float on the current file's directory
- **WHEN** the user is editing `lua/plugins/oil.lua` and presses `<leader>E`
- **THEN** a floating oil window opens listing the `lua/plugins/` directory

#### Scenario: Fallback to cwd
- **WHEN** the current buffer has no file on disk (an empty start buffer or a scratch buffer) and the user presses `<leader>E`
- **THEN** the floating oil window lists the current working directory

#### Scenario: Filesystem edits apply on save
- **WHEN** the user renames an entry in the oil float and writes the buffer, confirming the action prompt
- **THEN** the file is renamed on disk

#### Scenario: Sidebar keeps directory buffers
- **WHEN** the user starts Neovim with `nvim .`
- **THEN** the directory opens in the sidebar explorer and no oil buffer is created

## MODIFIED Requirements

### Requirement: Shell UI plugins
The configuration SHALL include: the sidebar file explorer (toggle on `<leader>e`), lualine.nvim (mode, branch, diff, diagnostics, filetype), trouble.nvim (panels under a `<leader>k` which-key group: workspace/buffer diagnostics, loclist, quickfix, LSP defs/refs panel, symbols outline — the old-config layout, freeing `<leader>x` for buffer-closing keymaps), todo-comments.nvim (TODO/FIXME highlighting, a TODO picker on `<leader>ft` and a Trouble panel on `<leader>xt`), and indent guides (`│`, with the current scope highlighted) that do not render in help, explorer, Trouble or mason windows.

#### Scenario: Explorer toggle
- **WHEN** the user presses `<leader>e`
- **THEN** the sidebar explorer opens showing the project tree, and pressing it again closes it

#### Scenario: Diagnostics panel
- **WHEN** the user presses `<leader>kd` with diagnostics present
- **THEN** a structured list of project diagnostics is shown and selecting an entry jumps to its location

#### Scenario: TODO picker
- **WHEN** the project contains `TODO:` and `FIXME:` comments and the user presses `<leader>ft`
- **THEN** a picker lists them and selecting one jumps to it

#### Scenario: Indent guides stay out of panels
- **WHEN** a code buffer and the explorer are visible side by side
- **THEN** the code buffer shows indent guides and the explorer shows none

### Requirement: Theme-derived folder icons
Explorer folder icons SHALL use the active colorscheme's `FolderIcon` group when it defines a foreground, and `#E5C07B` otherwise, and SHALL follow colorscheme changes without a restart.

#### Scenario: Folder colour for third-party themes
- **WHEN** tokyonight-night is active
- **THEN** explorer folder icons are `#E5C07B`

#### Scenario: Folder colour from a theme that provides one
- **WHEN** vale-day is active
- **THEN** explorer folder icons use vale-day's `FolderIcon` colour

## REMOVED Requirements

### Requirement: Plugin-free session restore with pins
**Reason**: Its explorer scenarios named neo-tree. The requirement is restated, with the same behaviour plus migration of previously saved explorer state, as "Automatic session restore with pins and explorer".
**Migration**: None for the user. Saved neo-tree state files are read once and carried over.

### Requirement: Neo-tree smart file opening
**Reason**: The explorer moves from neo-tree to the snacks explorer.
**Migration**: Same keys: see "Explorer file opening".

### Requirement: Neo-tree hide lists and advanced yank
**Reason**: The explorer moves from neo-tree to the snacks explorer.
**Migration**: Same lists and `Y` chooser: see "Explorer hide lists and advanced yank". `H` reveals hidden entries.

### Requirement: Oil floating explorer
**Reason**: It defined oil's coexistence in terms of neo-tree.
**Migration**: Same behaviour: see "Oil floating explorer alongside the sidebar".
