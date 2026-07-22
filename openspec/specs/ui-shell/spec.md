# ui-shell Specification

## Purpose
TBD - created by syncing change setup-nvim-config. Update Purpose after archive.

## Requirements

### Requirement: Theme switcher with persistence
The configuration SHALL install catppuccin, tokyonight, kanagawa, gruvbox, rose-pine, nightfox, onedark, everforest, and nord, and provide a themery.nvim picker (`<leader>ut`) whose selection persists across restarts. Themery's self-modifying block SHALL be confined to a dedicated small file.

#### Scenario: Theme persists
- **WHEN** the user selects kanagawa in the themery picker and restarts Neovim
- **THEN** kanagawa is the active colorscheme after restart

### Requirement: Telescope fuzzy finding
The configuration SHALL provide telescope.nvim with the fzf-native sorter, the old config's ignore patterns (build artifacts, VCS dirs, binary and lock files) for find-files and live-grep, hidden files included, and keymaps for: find files, live grep, buffers, help tags, recent files, and resume, under a `<leader>f` which-key group. `<leader><leader>` SHALL open the find-files picker and `<leader>ff` SHALL resume the last-used picker with its previous query and results. Result rows SHALL keep stable alignment while the selection moves: the selection caret and entry prefix MUST have equal display width, since telescope re-renders visited rows and a width mismatch accumulates a residual shift.

#### Scenario: Live grep
- **WHEN** the user presses the live-grep keymap and types a pattern
- **THEN** matching lines across the project appear via ripgrep and selecting one jumps to it

#### Scenario: Quick find files
- **WHEN** the user presses `<leader><leader>`
- **THEN** the find-files picker opens

#### Scenario: Resume last picker
- **WHEN** the user runs a live-grep search, closes it, and presses `<leader>ff`
- **THEN** the live-grep picker reopens with the previous query and results

#### Scenario: Stable rows while cycling
- **WHEN** the user moves the selection down and up across many results
- **THEN** every row's text keeps its original column, with no accumulating right-shift

### Requirement: Which-key discoverability
The configuration SHALL load which-key.nvim with named groups for all leader prefixes (find, git, debug, code, ui, trouble) so pressing `<leader>` shows a labeled popup. All plugin keymaps SHALL carry `desc`.

#### Scenario: Leader popup
- **WHEN** the user presses `<leader>` and waits
- **THEN** a popup lists the named groups and bindings with human-readable descriptions

### Requirement: Shell UI plugins
The configuration SHALL include: neo-tree.nvim (file explorer toggle on `<leader>e`), lualine.nvim (mode, branch, diff, diagnostics, filetype), trouble.nvim (panels under a `<leader>k` which-key group: workspace/buffer diagnostics, loclist, quickfix, LSP defs/refs panel, symbols outline — the old-config layout, freeing `<leader>x` for buffer-closing keymaps), todo-comments.nvim (TODO/FIXME highlighting + telescope picker), and indent-blankline.nvim (indent guides).

#### Scenario: Explorer toggle
- **WHEN** the user presses `<leader>e`
- **THEN** neo-tree opens showing the project tree, and pressing it again closes it

#### Scenario: Diagnostics panel
- **WHEN** the user presses `<leader>kd` with diagnostics present
- **THEN** a structured list of project diagnostics is shown and selecting an entry jumps to its location

### Requirement: Larger Trouble symbols outline
The Trouble document symbols outline SHALL open as a right-side split sized to 35% of the editor width, and all configured symbols-outline entry points SHALL use that same size.

#### Scenario: Symbols outline width
- **WHEN** the user opens the Trouble symbols outline from any configured symbols keymap
- **THEN** the outline opens on the right at 35% of the editor width

#### Scenario: Other Trouble modes unchanged
- **WHEN** the user opens Trouble diagnostics, quickfix, loclist, or LSP defs/refs panels
- **THEN** those modes keep their existing layout behavior unless explicitly configured otherwise

### Requirement: Bufferline with pinnable buffers
The configuration SHALL show open buffers in a bufferline.nvim top bar with diagnostics indicators, close buttons, and a pin toggle keymap; pinned buffers SHALL sort before unpinned ones.

#### Scenario: Pin a buffer
- **WHEN** the user presses the pin keymap on a buffer
- **THEN** the buffer shows a pin indicator and moves to the pinned section of the bufferline

### Requirement: Plugin-free session restore with pins
The configuration SHALL provide automatic session management through auto-session: sessions are keyed per project (cwd), saved automatically on exit, and restored automatically when Neovim starts with no file arguments in a directory that has a saved session. `sessionoptions` SHALL include `buffers` and `globals` so open buffers, window layout, and `vim.g.BufferlinePinnedBuffers` persist in the session file, and a post-restore hook SHALL re-sync bufferline's pinned group from that global so previously pinned buffers show as pinned again. Session keymaps SHALL live under a `<leader>q` which-key group (save, restore, search picker, delete, toggle auto-save). Breakpoint restoration stays with the workspace module and SHALL still fire for session-restored buffers.

#### Scenario: Automatic session round-trip
- **WHEN** the user has several buffers open (two pinned), quits Neovim, and reopens it in the same directory with no file arguments
- **THEN** the same buffers and window layout return automatically and the two buffers are pinned again

#### Scenario: No restore with file arguments
- **WHEN** the user opens Neovim with an explicit file argument (`nvim foo.py`)
- **THEN** no session is restored and the requested file opens normally

#### Scenario: Breakpoints after auto-restore
- **WHEN** a session restore brings back a file that has persisted breakpoints
- **THEN** those breakpoints are registered with nvim-dap

#### Scenario: Neo-tree state restored with the session
- **WHEN** the user has neo-tree open with several folders expanded, quits, and the session is restored (automatically or manually)
- **THEN** neo-tree reopens with the same folders expanded

#### Scenario: Closed neo-tree stays closed
- **WHEN** neo-tree was closed at exit and the session is restored
- **THEN** neo-tree does not open

#### Scenario: Neo-tree state survives :restart
- **WHEN** the user expands folders or opens/closes the tree and the process ends without exit hooks (`:restart`, crash, kill)
- **THEN** the latest tree state was already persisted by neo-tree's render/window events and is restored next time

#### Scenario: Unopened tree keeps its memory
- **WHEN** a session ends in which neo-tree was never opened
- **THEN** the previously saved expanded-folders list is preserved, not wiped

#### Scenario: Buffers and pins survive :restart
- **WHEN** the user opens new files, closes others, and changes pins, then the process ends without exit hooks (`:restart`, crash, kill)
- **THEN** on the next start the restored session is reconciled against the change-time workspace snapshot: since-opened files are re-added, since-closed unmodified buffers are dropped, and the pin set matches the latest state

#### Scenario: Stale session pins corrected
- **WHEN** a buffer was unpinned after the last clean session save and the process hard-exited
- **THEN** after restore that buffer is not pinned

### Requirement: Noice cmdline and message UI
The configuration SHALL use noice.nvim for cmdline rendering and message routing only: the cmdline SHALL render in the classic bottom-row position (no centered command-palette popup), and noice's LSP overrides, hover handler, and signature handler SHALL stay disabled so LSP documentation rendering is owned by native Neovim and blink.cmp. Mode messages (`msg_showmode`, e.g. macro recording) SHALL be routed to a visible notification view rather than suppressed.

#### Scenario: Bottom cmdline
- **WHEN** the user presses `:`
- **THEN** the command line renders at the bottom of the screen, not as a centered popup

#### Scenario: No noice LSP interference
- **WHEN** an LSP hover or signature window is opened
- **THEN** noice does not render or override it

### Requirement: Undotree access
The configuration SHALL expose Neovim 0.12's built-in `:Undotree` via a keymap.

#### Scenario: Open undotree
- **WHEN** the user presses the undotree keymap
- **THEN** the built-in undo tree view opens for the current buffer

### Requirement: Neo-tree smart file opening
The neo-tree window SHALL be 45 columns wide, and pressing `w` or `<cr>` on a file SHALL open it via nvim-window-picker: with at most one eligible target window the file opens directly; with multiple eligible windows a picker prompts for the destination, excluding neo-tree, notification, terminal, and quickfix windows. Pressing `w` or `<cr>` on a directory SHALL toggle it. The old config's hide lists SHALL apply (by name: `.git`, cache dirs, `bin`/`obj`, `node_modules`, `.next`; by pattern: venvs and `*.egg-info`; never shown: `__pycache__`), and `Y` SHALL open the advanced-yank chooser copying the node's filename, stem, absolute path, cwd-relative path, home-relative path, or extension to the clipboard.

#### Scenario: Open with single window
- **WHEN** one editing window exists and the user presses `w` on a file in neo-tree
- **THEN** the file opens in that window without any picker prompt

#### Scenario: Open with multiple windows
- **WHEN** two editing windows exist and the user presses `w` on a file in neo-tree
- **THEN** a window-picker overlay appears and the file opens in the chosen window

#### Scenario: Advanced yank
- **WHEN** the user presses `Y` on a file in neo-tree and picks "Path relative to CWD"
- **THEN** that relative path lands in the system clipboard

#### Scenario: Noise hidden
- **WHEN** a project contains `__pycache__` and `node_modules` directories
- **THEN** `__pycache__` never appears and `node_modules` is hidden by default

### Requirement: Telescope-backed vim.ui.select
The configuration SHALL register telescope-ui-select as the `vim.ui.select` provider so all selection prompts (DAP configuration chooser, code actions) render as a telescope picker.

#### Scenario: DAP configuration chooser
- **WHEN** the user starts `dap.continue()` with multiple debug configurations available
- **THEN** a telescope picker lists the configurations by name and selecting one starts that session

#### Scenario: Code action selection
- **WHEN** the user triggers a code action with multiple actions available
- **THEN** the actions appear in a telescope picker

### Requirement: Macro recording visibility
The statusline SHALL show a highlighted `REC @<register>` indicator while a macro is being recorded, appearing on RecordingEnter and disappearing on RecordingLeave.

#### Scenario: Indicator during recording
- **WHEN** the user starts recording with `qq` and later stops with `q`
- **THEN** the statusline shows `REC @q` for the whole recording and clears it when recording stops

### Requirement: Extensible toggleterm terminal
The configuration SHALL provide terminals via toggleterm.nvim: `<C-t>` toggles (count-prefixed for numbered terminals, works in normal/insert/terminal modes), a `<leader>T` which-key group covers directions (horizontal/vertical/float), terminals 1-4, toggle-all, named creation, rename, and sending the current line or visual selection; terminal buffers get local keymaps (`<C-\>`/`jk` to normal mode, `<C-h/j/k/l>` window navigation). Interactive TUI terminals (lazygit) SHALL be excluded from the `jk` and `<C-h/j/k/l>` maps via a buffer flag — a pending `jk` map delays every `j` keystroke and fast `j`/`k` navigation would exit terminal mode — keeping only `<C-\>` as a deliberate escape. The terminal module SHALL expose a hook registry (`register_on_create`, `register_on_open`, `register_on_close`, `register_on_stdout`, `register_on_stderr`, `register_on_exit`) callable from any other module, with hooks registered at any time firing for subsequent terminal events.

#### Scenario: Toggle and escape
- **WHEN** the user presses `<C-t>` and then `jk` inside the terminal
- **THEN** a horizontal terminal opens in insert mode and `jk` returns to normal mode

#### Scenario: External module registers a hook
- **WHEN** another module calls `register_on_create` with a callback after the terminal module is set up, and a terminal is later created
- **THEN** the callback runs with the terminal object

### Requirement: Notification history picker
The configuration SHALL open the message/notification history in a telescope picker via `<leader>fn`.

#### Scenario: Browse past notifications
- **WHEN** notifications have been shown and the user presses `<leader>fn`
- **THEN** a telescope picker lists the message history

### Requirement: Per-tab buffer scoping via scope.nvim
The configuration SHALL scope listed buffers per tabpage via scope.nvim, so the bufferline shows only buffers opened in the current tab. Scope state SHALL persist across sessions: auto-session SHALL run `ScopeSaveState` before saving and `ScopeLoadState` before restoring a session, and `sessionoptions` SHALL retain `tabpages` and `globals`.

#### Scenario: Buffers isolated per tab
- **WHEN** the user opens file A in tab 1, creates a new tab, and opens file B
- **THEN** tab 2's bufferline shows only B, and switching back to tab 1 shows only A

#### Scenario: Scope state survives a session round-trip
- **WHEN** the user exits Neovim with two tabs holding different buffer sets and restarts into the restored session
- **THEN** each restored tab shows only its own buffers

### Requirement: Winbar symbol breadcrumbs
The configuration SHALL display a VSCode-style breadcrumb in the winbar showing the path of the symbol (namespace/class/function) enclosing the cursor, backed by barbecue.nvim and nvim-navic. The breadcrumb SHALL update automatically as the cursor moves and SHALL be shown only in windows displaying editable code buffers — it MUST NOT appear in neo-tree, terminal/toggleterm, or other plugin panels and floating windows.

#### Scenario: Breadcrumb follows the cursor
- **WHEN** the cursor is inside a function within a code buffer with an LSP that provides document symbols
- **THEN** the winbar shows the enclosing symbol path (e.g. `file › Class › Method`)
- **AND** moving the cursor into a different symbol updates the breadcrumb

#### Scenario: No breadcrumb on non-code windows
- **WHEN** focus is in the neo-tree explorer, a terminal, or another plugin panel
- **THEN** no breadcrumb winbar is shown for that window

### Requirement: Buffer tooling indicators in the statusline
The statusline SHALL show icon-distinguished, buffer-scoped indicators for the active LSP clients, conform formatters, and nvim-lint linters of the current buffer. Each indicator SHALL read global state keyed by the current buffer (`vim.lsp.get_clients`, `conform.list_formatters`, `lint.linters_by_ft`), carry its own icon and color so the three are visually distinguishable, and render nothing when its list is empty.

#### Scenario: Indicators reflect the current buffer
- **WHEN** a Python buffer is open with basedpyright + ruff attached, ruff configured as formatter, and ruff + mypy as linters
- **THEN** the statusline shows an LSP indicator listing the clients, a formatter indicator listing the formatters, and a linter indicator listing the linters, each with its distinguishing icon

#### Scenario: Empty indicators hide
- **WHEN** a buffer has no linters configured for its filetype
- **THEN** the linter indicator renders nothing (no empty icon or label)

### Requirement: Registrable statusline widgets
The statusline SHALL include a bridge component that renders statusline widgets registered by any code — language packs (via the framework's `statusline` field) or a plugin's own setup — through a public `register()` API on the statusline module, evaluated at render time so widgets from lazily-loaded plugins appear once available. Registration SHALL append (never replace), so registrants do not clobber one another regardless of order. A widget SHALL be shown only when its `cond` (if any) holds and its `render()` returns a non-empty string. The Python pack SHALL contribute a venv widget that shows `🐍 <venv-name>` for Python buffers and renders nothing when no virtualenv is active.

#### Scenario: Active venv shown for Python buffers
- **WHEN** a virtualenv is selected (via venv-selector) and a Python buffer is focused
- **THEN** the statusline shows `🐍 <venv-name>`

#### Scenario: No venv hides the widget
- **WHEN** no virtualenv is active, or the focused buffer is not Python
- **THEN** the venv widget renders nothing

#### Scenario: A plugin registers its own widget
- **WHEN** a plugin calls the statusline module's `register()` in its setup with a widget spec
- **THEN** that widget renders in the statusline alongside pack-contributed widgets, without either clobbering the other
