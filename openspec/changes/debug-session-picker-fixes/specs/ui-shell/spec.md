# ui-shell Delta

## MODIFIED Requirements

### Requirement: Telescope fuzzy finding
The configuration SHALL provide telescope.nvim with the fzf-native sorter and keymaps for: find files, live grep, buffers, help tags, recent files, and resume, under a `<leader>f` which-key group. `<leader><leader>` SHALL open the find-files picker and `<leader>ff` SHALL resume the last-used picker with its previous query and results. Result rows SHALL keep stable alignment while the selection moves: the selection caret and entry prefix MUST have equal display width, since telescope re-renders visited rows and a width mismatch accumulates a residual shift.

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

### Requirement: Noice cmdline and message UI
The configuration SHALL use noice.nvim for cmdline rendering and message routing only: the cmdline SHALL render in the classic bottom-row position (no centered command-palette popup), and noice's LSP overrides, hover handler, and signature handler SHALL stay disabled so LSP documentation rendering is owned by native Neovim and blink.cmp. Mode messages (`msg_showmode`, e.g. macro recording) SHALL be routed to a visible notification view rather than suppressed.

#### Scenario: Bottom cmdline
- **WHEN** the user presses `:`
- **THEN** the command line renders at the bottom of the screen, not as a centered popup

#### Scenario: No noice LSP interference
- **WHEN** an LSP hover or signature window is opened
- **THEN** noice does not render or override it

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

## ADDED Requirements

### Requirement: Macro recording visibility
The statusline SHALL show a highlighted `REC @<register>` indicator while a macro is being recorded, appearing on RecordingEnter and disappearing on RecordingLeave.

#### Scenario: Indicator during recording
- **WHEN** the user starts recording with `qq` and later stops with `q`
- **THEN** the statusline shows `REC @q` for the whole recording and clears it when recording stops

### Requirement: Extensible toggleterm terminal
The configuration SHALL provide terminals via toggleterm.nvim: `<C-t>` toggles (count-prefixed for numbered terminals, works in normal/insert/terminal modes), a `<leader>T` which-key group covers directions (horizontal/vertical/float), terminals 1-4, toggle-all, named creation, rename, and sending the current line or visual selection; terminal buffers get local keymaps (`<C-\>`/`jk` to normal mode, `<C-h/j/k/l>` window navigation). The terminal module SHALL expose a hook registry (`register_on_create`, `register_on_open`, `register_on_close`, `register_on_stdout`, `register_on_stderr`, `register_on_exit`) callable from any other module, with hooks registered at any time firing for subsequent terminal events.

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
