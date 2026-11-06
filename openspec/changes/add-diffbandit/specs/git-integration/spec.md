# Spec Delta

## ADDED Requirements

### Requirement: Diff review via diffbandit.nvim
The configuration SHALL install diffbandit.nvim from `CoreyKaylor/diffbandit.nvim` alongside diffview.nvim, constrained to its tagged releases below 1.0, so that a plugin update moves only to a newer release and never to an untagged commit. The existing diffview, Neogit, gitsigns and git-conflict keymaps and integrations SHALL keep their behavior.

#### Scenario: Both diff viewers available
- **WHEN** the user presses `<leader>gdd` and, in another tab, `<leader>gxx`
- **THEN** the first opens a diffview tab and the second opens a diffbandit view of the working-tree changes

#### Scenario: Updates follow releases
- **WHEN** the user runs a plugin update while diffbandit's default branch has commits newer than its latest release tag
- **THEN** diffbandit is offered only the newest release tag below 1.0, and the lockfile records that revision

### Requirement: Diffbandit keymaps under `<leader>gx`
The configuration SHALL map diffbandit under a `<leader>gx` which-key group, every key with a description:

| Key | Action |
|---|---|
| `gxx` | all working-tree changes, including untracked files |
| `gxs` | staged changes only |
| `gxf` | the current file |
| `gxc` | toggle the commit panel |
| `gxb` | branch comparison |
| `gxl` | the commit log |
| `gxm` | diffbandit's menu |
| `gxq` | close the diffbandit view in the current tab |

#### Scenario: Group shown in which-key
- **WHEN** the user presses `<leader>g` and waits
- **THEN** which-key lists a `diffbandit` group on `x`, and pressing `x` lists all eight keys with their descriptions

#### Scenario: Close from the keymap
- **WHEN** a diffbandit view is open in the current tab and the user presses `<leader>gxq`
- **THEN** the view and its tab close

### Requirement: Diffbandit staging key does not use the leader key
Inside diffbandit's diff views, commit panel and folder views, toggling the stage of a hunk or file, toggling amend mode, and expanding or collapsing a folder SHALL be bound to `-` instead of `<Space>`, so that pressing these keys never waits for a leader-key timeout and leader keymaps keep working inside these views.

#### Scenario: Stage a hunk
- **WHEN** the cursor is on an unstaged hunk in a diffbandit Git diff and the user presses `-`
- **THEN** the hunk is staged immediately, and pressing `-` again unstages it

#### Scenario: Leader still works inside the view
- **WHEN** the user presses `<leader>ff` inside a diffbandit view
- **THEN** the find-files picker opens and nothing is staged

### Requirement: Diffbandit views close with the workspace
When a worktree switch starts, every open diffbandit view in every tab, including standalone commit panels, SHALL be closed before the switch checks for unsaved buffers. The switch can therefore never write diffbandit's commit-message window, whose write creates a commit. The switch SHALL then proceed as it would without diffbandit. Unsaved edits in diffbandit's editable pane SHALL block the switch like any other unsaved buffer.

#### Scenario: Switch with a view open
- **WHEN** a diffbandit view is open in one tab, nothing is modified, and the user switches worktree
- **THEN** the view is closed, the switch completes, and the outgoing workspace's saved session contains no diffbandit tab

#### Scenario: Unfinished commit message
- **WHEN** the commit panel holds a typed but uncommitted message and the user switches worktree, choosing "Save all and switch"
- **THEN** no commit is created, the panel is closed, and diffbandit restores the message the next time its commit panel opens in that repository

#### Scenario: Cancelled switch
- **WHEN** a diffbandit view is open, another buffer has unsaved edits, and the user cancels the switch
- **THEN** the workspace stays where it was and the diffbandit view is closed

#### Scenario: Unsaved edit in the editable pane
- **WHEN** the user has an unsaved edit in diffbandit's right pane and starts a worktree switch
- **THEN** the switch asks to save all or cancel, exactly as for any modified buffer

### Requirement: Diffbandit views stay out of the exit session
When Neovim exits and the session is saved automatically, every open diffbandit view SHALL be closed before the session is written, so that restoring the session never brings back diffbandit's windows or scratch buffers. A manual session save while Neovim keeps running SHALL leave open views as they are.

#### Scenario: Exit with a view open
- **WHEN** a diffbandit view is open, the user quits Neovim, and then restarts it in the same directory
- **THEN** the session restores the user's normal tabs and buffers, with no diffbandit tab or empty diff panes

#### Scenario: Manual save keeps the view
- **WHEN** a diffbandit view is open and the user saves the session with `<leader>qs`
- **THEN** the view stays open
