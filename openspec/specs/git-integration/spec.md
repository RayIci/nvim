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
When a gitcommit buffer opens with no message yet (fresh commit), the configuration SHALL automatically generate a conventional commit title and description from the staged diff via CopilotChat.nvim in headless mode (no chat window) and insert it at the top of the buffer, once per buffer. Buffers arriving with an existing message (amend/reword) SHALL NOT trigger generation. A buffer-local keymap SHALL allow manual (re)generation.

#### Scenario: Automatic message on fresh commit
- **WHEN** the user runs `git commit` with staged changes and the commit buffer opens empty
- **THEN** a generated title and description are inserted into the buffer without any chat window opening, ready to edit before saving

#### Scenario: Amend untouched
- **WHEN** the user runs `git commit --amend` and the buffer opens with the previous message
- **THEN** no automatic generation happens

#### Scenario: Manual regeneration
- **WHEN** the user presses the generate keymap in a commit buffer
- **THEN** a fresh message is generated headlessly and inserted
