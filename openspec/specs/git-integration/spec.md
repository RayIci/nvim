# git-integration Specification

## Purpose
TBD - created by syncing change setup-nvim-config. Update Purpose after archive.

## Requirements

### Requirement: In-buffer git via gitsigns
The configuration SHALL show git hunk signs, current-line blame (toggleable), and provide hunk actions (stage, reset, preview, next/prev) via gitsigns.nvim keymaps under a `<leader>g` which-key group.

#### Scenario: Hunk navigation and stage
- **WHEN** a tracked file has unstaged modifications
- **THEN** hunk signs render and `]h`/`[h` navigate hunks and the stage keymap stages the hunk under the cursor

### Requirement: Lazygit floating terminal
The configuration SHALL open lazygit in a floating terminal window via a keymap (`<leader>gg`), closing the float automatically when lazygit exits, implemented without an extra plugin.

#### Scenario: Open and close lazygit
- **WHEN** the user presses `<leader>gg`
- **THEN** lazygit opens in a centered float in insert/terminal mode, and quitting lazygit closes the float

### Requirement: Copilot-generated commit messages
The configuration SHALL provide a keymap in `gitcommit` buffers that uses CopilotChat.nvim with the staged diff to generate a conventional commit message with a description body and insert it into the commit buffer.

#### Scenario: Generate message in commit buffer
- **WHEN** the user opens a commit buffer with staged changes and presses the generate keymap
- **THEN** a commit title and description generated from the staged diff are inserted into the buffer for review before saving
