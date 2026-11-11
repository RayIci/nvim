# Spec Delta

## ADDED Requirements

### Requirement: Fuzzy finding
The configuration SHALL provide fuzzy pickers under a `<leader>f` which-key group for: find files, live grep, buffers, help tags, recent files, grep word under cursor, diagnostics, keymaps, workspace symbols and resume. `<leader><leader>` SHALL open find-files and `<leader>ff` SHALL resume the last-used picker with its previous query and results.

#### Scenario: Live grep
- **WHEN** the user presses `<leader>fg` and types a pattern
- **THEN** matching lines across the project appear via ripgrep and selecting one jumps to it

#### Scenario: Quick find files
- **WHEN** the user presses `<leader><leader>`
- **THEN** the find-files picker opens and lists hidden files but not `node_modules/` or `.git/` contents

#### Scenario: Resume last picker
- **WHEN** the user runs a live-grep search, closes it, and presses `<leader>ff`
- **THEN** the live-grep picker reopens with the previous query and results

### Requirement: Picker ignore rules
Find-files and live-grep SHALL include hidden files and SHALL skip the old config's ignore patterns: build artifacts, VCS directories, dependency folders, and binary, image, font, archive and lock files.

#### Scenario: Dependencies and binaries skipped
- **WHEN** the user live-greps for a word that also occurs in `node_modules/` and in a `.lock` file
- **THEN** neither of those matches is listed, while a match in a hidden `.env.example` file is

### Requirement: Picker-backed selection prompts
`vim.ui.select` and `vim.ui.input` SHALL render as picker and input windows rather than the cmdline inputlist, so every selection prompt (DAP configuration chooser, code actions, session search, virtualenv selection) looks and behaves the same. Code-action entries SHALL show the name of the server offering each action.

#### Scenario: DAP configuration chooser
- **WHEN** the user starts `dap.continue()` with multiple debug configurations available
- **THEN** a picker lists the configurations by name and selecting one starts that session

#### Scenario: Code action selection
- **WHEN** the user triggers a code action with actions available from two servers
- **THEN** the actions appear in a picker, each labelled with its server's name

### Requirement: Native cmdline and notifications
The cmdline SHALL be Neovim's own bottom-row cmdline, using Neovim's built-in message UI so that messages longer than the cmdline open in a pager instead of a "Press ENTER" prompt. Notifications (`vim.notify`) SHALL render through the snacks notifier, which `<leader>un` dismisses. Exiting with `:qa` or `:restart` MUST NOT stop at a prompt that nothing answers.

#### Scenario: Long output does not block
- **WHEN** the user runs a command that prints more lines than the cmdline holds, such as `:messages`
- **THEN** the output opens in a pager window that closes with `q`, and no "Press ENTER" prompt appears

#### Scenario: Bottom cmdline
- **WHEN** the user presses `:`
- **THEN** the command line renders at the bottom of the screen, not as a popup

#### Scenario: Dismiss notifications
- **WHEN** several notifications are visible and the user presses `<leader>un`
- **THEN** all of them close

#### Scenario: Restart does not hang
- **WHEN** a plugin prints a message during exit and the user runs `:restart`
- **THEN** Neovim restarts without waiting for a key press

## MODIFIED Requirements

### Requirement: Shell UI plugins
The configuration SHALL include: neo-tree.nvim (file explorer toggle on `<leader>e`), lualine.nvim (mode, branch, diff, diagnostics, filetype), trouble.nvim (panels under a `<leader>k` which-key group: workspace/buffer diagnostics, loclist, quickfix, LSP defs/refs panel, symbols outline — the old-config layout, freeing `<leader>x` for buffer-closing keymaps), todo-comments.nvim (TODO/FIXME highlighting, a TODO picker on `<leader>ft` and a Trouble panel on `<leader>xt`), and indent guides (`│`, with the current scope highlighted) that do not render in help, explorer, Trouble or mason windows.

#### Scenario: Explorer toggle
- **WHEN** the user presses `<leader>e`
- **THEN** neo-tree opens showing the project tree, and pressing it again closes it

#### Scenario: Diagnostics panel
- **WHEN** the user presses `<leader>kd` with diagnostics present
- **THEN** a structured list of project diagnostics is shown and selecting an entry jumps to its location

#### Scenario: TODO picker
- **WHEN** the project contains `TODO:` and `FIXME:` comments and the user presses `<leader>ft`
- **THEN** a picker lists them and selecting one jumps to it

#### Scenario: Indent guides stay out of panels
- **WHEN** a code buffer and the explorer are visible side by side
- **THEN** the code buffer shows indent guides and the explorer shows none

### Requirement: Notification history picker
The configuration SHALL open the notification history in a picker via `<leader>fn`.

#### Scenario: Browse past notifications
- **WHEN** notifications have been shown and the user presses `<leader>fn`
- **THEN** a picker lists the past notifications, newest first, with their level and time

## REMOVED Requirements

### Requirement: Telescope fuzzy finding
**Reason**: Pickers move to the snacks picker. The keys and ignore rules carry over unchanged.
**Migration**: See the added requirement "Fuzzy finding". The keys are identical.

### Requirement: Stable telescope row alignment
**Reason**: It described a telescope rendering quirk (caret and prefix width). The snacks picker does not re-render rows that way.
**Migration**: None needed.

### Requirement: Noice cmdline and message UI
**Reason**: noice was configured to imitate the native bottom cmdline. Its remaining job, routing messages, is done by the snacks notifier, and the exit-prompt workaround it needed goes with it.
**Migration**: See the added requirement "Native cmdline and notifications". The macro-recording indicator is unaffected: it is in the statusline (requirement "Macro recording visibility").

### Requirement: Telescope-backed vim.ui.select
**Reason**: Selection prompts move to the snacks picker together with the other pickers.
**Migration**: See the added requirement "Picker-backed selection prompts".
