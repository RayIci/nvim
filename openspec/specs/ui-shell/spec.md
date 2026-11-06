# ui-shell Specification

## Purpose
Defines the editor shell around the buffers: colorschemes and the theme picker, fuzzy finding, which-key, the neo-tree and oil file explorers, the bufferline and session restore, the cmdline and notification UI, terminals, winbar breadcrumbs, and the statusline.

## Requirements

### Requirement: Theme switcher with persistence
The configuration SHALL install catppuccin, tokyonight, kanagawa, gruvbox, rose-pine, nightfox, onedark, everforest, and nord, and provide a themery.nvim picker (`<leader>ut`) whose selection persists across restarts. Themery's self-modifying block SHALL be confined to a dedicated small file.

#### Scenario: Theme persists
- **WHEN** the user selects kanagawa in the themery picker and restarts Neovim
- **THEN** kanagawa is the active colorscheme after restart

### Requirement: Configuration colorschemes in the theme picker
The picker SHALL also list, at the top, every colorscheme defined by a file in the configuration's own `colors/` directory (such as the generated `vale-night` and `vale-day`), discovered at startup so that newly generated themes appear without editing the picker configuration. On first launch, when no selection has been persisted, `vale-night` SHALL be the active colorscheme.

#### Scenario: Vale in the picker
- **WHEN** the user opens the themery picker
- **THEN** `vale-night` and `vale-day` are listed among the configuration's own colorschemes at the top, and selecting one applies it with live preview

#### Scenario: New theme appears without config edits
- **WHEN** a new colorscheme file `colors/ocean-night.lua` is added to the configuration and Neovim restarts
- **THEN** the themery picker lists `ocean-night` at the top, with no change to `lua/plugins/theme.lua`

#### Scenario: First-launch default
- **WHEN** Neovim starts with no persisted themery selection
- **THEN** `vale-night` is the active colorscheme

### Requirement: Telescope fuzzy finding
The configuration SHALL provide telescope.nvim with the fzf-native sorter, the old config's ignore patterns (build artifacts, VCS dirs, binary and lock files) for find-files and live-grep, hidden files included, and keymaps for: find files, live grep, buffers, help tags, recent files, and resume, under a `<leader>f` which-key group. `<leader><leader>` SHALL open the find-files picker and `<leader>ff` SHALL resume the last-used picker with its previous query and results.

#### Scenario: Live grep
- **WHEN** the user presses the live-grep keymap and types a pattern
- **THEN** matching lines across the project appear via ripgrep and selecting one jumps to it

#### Scenario: Quick find files
- **WHEN** the user presses `<leader><leader>`
- **THEN** the find-files picker opens

#### Scenario: Resume last picker
- **WHEN** the user runs a live-grep search, closes it, and presses `<leader>ff`
- **THEN** the live-grep picker reopens with the previous query and results

### Requirement: Stable telescope row alignment
Telescope result rows SHALL keep stable alignment while the selection moves: the selection caret and entry prefix MUST have equal display width, since telescope re-renders visited rows and a width mismatch accumulates a residual shift.

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

### Requirement: Session-persisted buffers and pins
`sessionoptions` SHALL include `buffers` and `globals` so open buffers, window layout, and `vim.g.BufferlinePinnedBuffers` persist in the session file, and a post-restore hook SHALL re-sync bufferline's pinned group from that global so previously pinned buffers show as pinned again.

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
The neo-tree window SHALL be 45 columns wide, and pressing `w` or `<cr>` on a file SHALL open it via nvim-window-picker: with at most one eligible target window the file opens directly; with multiple eligible windows a picker prompts for the destination, excluding neo-tree, notification, terminal, and quickfix windows. Pressing `w` or `<cr>` on a directory SHALL toggle it.

#### Scenario: Open with single window
- **WHEN** one editing window exists and the user presses `w` on a file in neo-tree
- **THEN** the file opens in that window without any picker prompt

#### Scenario: Open with multiple windows
- **WHEN** two editing windows exist and the user presses `w` on a file in neo-tree
- **THEN** a window-picker overlay appears and the file opens in the chosen window

### Requirement: Neo-tree hide lists and advanced yank
The old config's neo-tree hide lists SHALL apply (by name: `.git`, cache dirs, `bin`/`obj`, `node_modules`, `.next`; by pattern: venvs and `*.egg-info`; never shown: `__pycache__` and conform's temporary `.conform.*` files), and `Y` SHALL open the advanced-yank chooser copying the node's filename, stem, absolute path, cwd-relative path, home-relative path, or extension to the clipboard.

#### Scenario: Advanced yank
- **WHEN** the user presses `Y` on a file in neo-tree and picks "Path relative to CWD"
- **THEN** that relative path lands in the system clipboard

#### Scenario: Noise hidden
- **WHEN** a project contains `__pycache__` and `node_modules` directories
- **THEN** `__pycache__` never appears and `node_modules` is hidden by default

#### Scenario: Formatter temp files stay hidden
- **WHEN** the user saves a Markdown file and conform formats it through a temporary `.conform.*` file in the same directory
- **THEN** the temporary file never appears in neo-tree, not even briefly

### Requirement: Oil floating explorer
The configuration SHALL provide oil.nvim as a secondary file explorer that coexists with neo-tree. Pressing `<leader>E` SHALL open oil in a floating window, listing the directory of the current buffer's file, or the current working directory when the buffer has no file on disk. Oil MUST NOT take over directory buffers: opening a directory (`nvim .`, `:e <dir>`) SHALL keep its current behavior, and neo-tree SHALL keep `<leader>e`.

#### Scenario: Float on the current file's directory
- **WHEN** the user is editing `lua/plugins/oil.lua` and presses `<leader>E`
- **THEN** a floating oil window opens listing the `lua/plugins/` directory

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

### Requirement: Oil buffer keymaps
Inside an oil buffer, `<BS>` in normal mode SHALL go to the parent directory, like `-`, while insert-mode `<BS>` keeps deleting characters. `g|` SHALL open the entry under the cursor in a vertical (side-by-side) split, `g-` in a horizontal (stacked) split, and `gR` SHALL refresh the listing. Oil MUST NOT shadow `<C-s>` (save) or `<C-h>`/`<C-l>` (tmux-navigator), so those global mappings keep working inside oil.

#### Scenario: Backspace goes up a directory
- **WHEN** the oil float lists `lua/plugins/` and the user presses `<BS>` in normal mode
- **THEN** the float lists `lua/`

#### Scenario: Split keys mirror tmux
- **WHEN** the cursor is on a file in the oil float and the user presses `g|`
- **THEN** the float closes and the file opens in a side-by-side split; with `g-` it opens in a stacked split

#### Scenario: Global Ctrl maps work inside oil
- **WHEN** focus is in an oil buffer and the user presses `<C-s>`, `<C-h>` or `<C-l>`
- **THEN** the global save or tmux-navigator mapping runs, not an oil action

### Requirement: Oil buffers stay out of winbar, bufferline and sessions
Oil windows SHALL show no winbar breadcrumb, and oil buffers SHALL NOT appear in the bufferline or be restored by sessions.

#### Scenario: Oil leaves no trace in tabs or sessions
- **WHEN** the user opens and closes the oil float, then quits and the session is restored
- **THEN** no `oil://` buffer appears in the bufferline before or after the restore

#### Scenario: Revisited oil buffers stay hidden
- **WHEN** the user toggles oil's trash view twice (`g\` then `g\`) or navigates back into a directory already visited
- **THEN** no `oil://` or `oil-trash://` buffer appears in the bufferline, during or after the oil session

#### Scenario: Oil open at quit or :restart
- **WHEN** oil is showing (in the float or a normal window) and the user runs `:qa` and reopens, or runs `:restart`
- **THEN** the restored session has no `oil://` buffer, and the window that showed oil shows its previous file

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
The configuration SHALL provide terminals via toggleterm.nvim: `<C-t>` toggles (count-prefixed for numbered terminals, works in normal/insert/terminal modes), and a `<leader>T` which-key group covers directions (horizontal/vertical/float), terminals 1-4, toggle-all, named creation, rename, and sending the current line or visual selection.

#### Scenario: Toggle and escape
- **WHEN** the user presses `<C-t>` and then `jk` inside the terminal
- **THEN** a horizontal terminal opens in insert mode and `jk` returns to normal mode

### Requirement: Terminal-local keymaps
Terminal buffers SHALL get local keymaps (`<C-\>`/`jk` to normal mode, `<C-h/j/k/l>` window navigation). Interactive TUI terminals (lazygit) SHALL be excluded from the `jk` and `<C-h/j/k/l>` maps via a buffer flag — a pending `jk` map delays every `j` keystroke and fast `j`/`k` navigation would exit terminal mode — keeping only `<C-\>` as a deliberate escape.

#### Scenario: TUI terminals keep j and k
- **WHEN** lazygit is open in a terminal and the user presses `j` and `k` quickly
- **THEN** lazygit receives both keys without delay and the terminal stays in terminal mode

### Requirement: Terminal hook registry
The terminal module SHALL expose a hook registry (`register_on_create`, `register_on_open`, `register_on_close`, `register_on_stdout`, `register_on_stderr`, `register_on_exit`) callable from any other module, with hooks registered at any time firing for subsequent terminal events.

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
The statusline SHALL include a bridge component that renders statusline widgets registered by any code — language packs (via the framework's `statusline` field) or a plugin's own setup — through a public `register()` API on the statusline module, evaluated at render time so widgets from lazily-loaded plugins appear once available. Registration SHALL append (never replace), so registrants do not clobber one another regardless of order.

#### Scenario: A plugin registers its own widget
- **WHEN** a plugin calls the statusline module's `register()` in its setup with a widget spec
- **THEN** that widget renders in the statusline alongside pack-contributed widgets, without either clobbering the other

### Requirement: Statusline widget visibility and venv widget
A statusline widget SHALL be shown only when its `cond` (if any) holds and its `render()` returns a non-empty string. The Python pack SHALL contribute a venv widget that shows `🐍 <venv-name>` for Python buffers and renders nothing when no virtualenv is active.

#### Scenario: Active venv shown for Python buffers
- **WHEN** a virtualenv is selected (via venv-selector) and a Python buffer is focused
- **THEN** the statusline shows `🐍 <venv-name>`

#### Scenario: No venv hides the widget
- **WHEN** no virtualenv is active, or the focused buffer is not Python
- **THEN** the venv widget renders nothing

### Requirement: Theme-derived statusline labels and folder icons
Configuration outside the colorscheme SHALL NOT reference any specific colorscheme. The statusline's macro-recording, LSP-client, formatter and linter labels SHALL take their foreground from the active colorscheme's `DiagnosticError`, `DiagnosticInfo`, `DiagnosticOk` and `Statement` groups respectively, falling back to `#ff5555`, `#7aa2f7`, `#9ece6a` and `#bb9af7` when that group has no foreground.

#### Scenario: Labels follow the theme
- **WHEN** the user switches from vale-night to kanagawa-wave without restarting
- **THEN** the LSP-client label shows kanagawa-wave's `DiagnosticInfo` colour

### Requirement: Theme-derived folder icons
Neo-tree folder icons SHALL use the active colorscheme's `FolderIcon` group when it defines a foreground, and `#E5C07B` otherwise.

#### Scenario: Folder colour for third-party themes
- **WHEN** tokyonight-night is active
- **THEN** neo-tree folder icons are `#E5C07B`

#### Scenario: Folder colour from a theme that provides one
- **WHEN** vale-day is active
- **THEN** neo-tree folder icons use vale-day's `FolderIcon` colour

### Requirement: Whole-workspace worktree switching
A managed worktree switch SHALL replace the whole workspace in the current Neovim instance. It SHALL save the outgoing session and workspace state before changing directory, then restore the destination's buffers, tabs, layout, pins, breakpoints, and explorer state. Listed buffers and per-tab membership from the outgoing workspace SHALL NOT leak into the destination.

#### Scenario: Switch between saved workspaces
- **WHEN** worktrees A and B have different open files, layouts, tab memberships, pins, breakpoints, and explorer expansion states, and the user switches from A to B
- **THEN** B's saved state is restored, A's editor state is no longer active, and switching back restores A's outgoing state

#### Scenario: Switch from any editing tab
- **WHEN** the source workspace has multiple tabs and hidden buffers
- **THEN** switching saves and replaces the entire workspace rather than changing only the active tab's directory or file

#### Scenario: Switch through the floating Git interface
- **WHEN** the user initiates switching from the configured Neogit worktree menu
- **THEN** the outgoing editing layout is saved without replacing it with the transient Git menu

#### Scenario: Select the active checkout
- **WHEN** the user selects the already active checkout
- **THEN** no session reset, directory change, or buffer teardown occurs

### Requirement: First-visit workspace initialization
When the destination has no saved session, a managed switch SHALL start without outgoing buffers, tabs, pins, or breakpoint registrations. Existing destination workspace state SHALL still be restored; when neither a session nor sidecar state exists, the workspace SHALL contain one clean editing buffer rooted at the destination, with the explorer closed.

#### Scenario: Brand-new worktree
- **WHEN** the user switches to a newly created worktree with no saved editor state
- **THEN** the target becomes cwd, one clean editing buffer is shown, and no old pins, tabs, breakpoints, or explorer expansions are inherited

#### Scenario: Sidecar state without a session
- **WHEN** a destination has persisted buffers, pins, breakpoints, or explorer state but no session file
- **THEN** applicable destination state is restored without importing the source workspace's state

### Requirement: Unsaved-edit transition guard
Before leaving a workspace, managed creation/switching SHALL detect modified buffers across all tabs and hidden buffers and offer "Save all and switch" or "Cancel", defaulting safely to cancellation. Failed writes and modified unnamed buffers that cannot be saved SHALL prevent teardown. Saved but uncommitted Git changes SHALL NOT by themselves prevent switching.

#### Scenario: Cancel with unsaved edits
- **WHEN** any source buffer is modified and the user cancels the transition
- **THEN** cwd and all source buffers remain active with their edits intact

#### Scenario: Save all before switching
- **WHEN** modified file-backed buffers exist and the user chooses to save all
- **THEN** every modified buffer is written successfully before outgoing state is discarded or cwd changes

#### Scenario: Hidden or unwritable buffer
- **WHEN** a hidden buffer or buffer in another tab cannot be written, or a modified unnamed buffer cannot be saved
- **THEN** switching is aborted with a visible explanation, and no unsaved buffer is discarded

#### Scenario: Saved Git changes remain in their checkout
- **WHEN** the source checkout contains saved, uncommitted changes but no unsaved editor buffers
- **THEN** switching is allowed and those changes remain in the source checkout

#### Scenario: Edits during creation
- **WHEN** the user modifies a source buffer while a worktree creation operation is in progress
- **THEN** the modified-buffer guard is applied again before the subsequent workspace teardown

### Requirement: Live-resource transition guard
A managed transition SHALL refuse to discard live Neovim terminal jobs or proceed while a debugging session is active. It SHALL identify the blocking resources without stopping them automatically. External terminal, tmux, server, and AI processes SHALL NOT be relocated or terminated by a workspace switch.

#### Scenario: Live terminal buffer
- **WHEN** a running terminal job would be discarded by the workspace reset
- **THEN** switching is refused with an explanation, and the job remains running in its original workspace

#### Scenario: Active debugger
- **WHEN** any debugging session is active
- **THEN** switching is refused without terminating or retargeting the debug session

#### Scenario: External process remains independent
- **WHEN** a successful switch occurs while an external process exists outside Neovim
- **THEN** the integration does not terminate it or claim its working directory has changed

### Requirement: Workspace persistence isolation
Managed transitions SHALL flush outgoing state under its original workspace identity before teardown and prevent transitional or stale callbacks from overwriting either workspace's saved state. Deferred restoration SHALL affect only the workspace for which it was scheduled. Existing empty snapshots SHALL be authoritative and distinct from missing snapshots.

#### Scenario: Save pending at switch time
- **WHEN** a source workspace save is pending when the user switches
- **THEN** the latest source state is saved under the source identity and the pending callback never writes it under the target identity

#### Scenario: Old restore callback fires late
- **WHEN** a pin, explorer, or session-load restoration callback from a previous workspace becomes ready after another workspace is active
- **THEN** it does not modify the active workspace or overwrite either workspace's stored state

#### Scenario: Empty state clears stale state
- **WHEN** the destination has an existing saved snapshot with empty buffers, pins, breakpoints, or explorer expansions
- **THEN** the corresponding stale runtime or session state is cleared rather than inherited from the source or an older destination session

#### Scenario: Missing sidecar preserves valid session state
- **WHEN** a destination session exists but a corresponding sidecar does not
- **THEN** valid state restored from that session is not erased merely because the sidecar is absent

#### Scenario: Rapid action requests
- **WHEN** another managed creation, switching, or deletion action is requested before the active action finishes
- **THEN** it is refused with a visible busy explanation rather than interleaving transitions

### Requirement: Recoverable workspace transition failures
A managed switch SHALL abort without changing cwd or discarding source buffers when saving outgoing state fails. A destination restore failure SHALL be reported distinctly from missing state, and recovery to the saved source workspace SHALL be attempted without overwriting destination state. If recovery fails, automatic writes SHALL stop and the user SHALL be told what remains recoverable.

#### Scenario: Outgoing save fails
- **WHEN** the session or sidecar save fails before teardown
- **THEN** switching is aborted, the source cwd and buffers remain active, and the error is shown

#### Scenario: Existing target session is broken
- **WHEN** the destination has a session file that fails to restore
- **THEN** the integration reports failure, does not replace the saved destination with an empty success-shaped session, and attempts to recover the saved source workspace

#### Scenario: Recovery also fails
- **WHEN** restoring both the destination and saved source fails
- **THEN** automatic writes are stopped and an error identifies the current directory and recoverable source state instead of announcing successful switching

### Requirement: Preserve ordinary session behavior
Outside managed transitions, existing startup restore, explicit-file startup, manual session mappings, per-tab scoping, and mutation-time persistence SHALL retain their behavior and storage locations. A managed switch SHALL explicitly save its outgoing workspace even when exit autosave is off, without changing that preference.

#### Scenario: Existing startup round-trip
- **WHEN** the user quits and reopens a checkout with no file arguments
- **THEN** its existing automatic session and workspace restoration continue to work

#### Scenario: Explicit file startup stays explicit
- **WHEN** the user starts Neovim with a file argument
- **THEN** the requested file opens without introducing automatic worktree switching or session restoration

#### Scenario: Exit autosave disabled
- **WHEN** the user has disabled exit autosave and performs a managed switch
- **THEN** the outgoing workspace is explicitly saved for the transition and the exit-autosave preference remains disabled

#### Scenario: Restart persistence remains intact
- **WHEN** buffers, pins, explorer state, or breakpoints change outside a managed transition and Neovim restarts without normal exit hooks
- **THEN** the existing mutation-time persistence continues to preserve the latest saved workspace state
