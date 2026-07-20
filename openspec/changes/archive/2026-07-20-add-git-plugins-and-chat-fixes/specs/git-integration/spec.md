# git-integration Delta

## ADDED Requirements

### Requirement: Diff and history UI via diffview.nvim
The configuration SHALL provide side-by-side diff views and git history browsing via diffview.nvim under a `<leader>gd` which-key group: `<leader>gdd`/`<leader>gdo` open the diff view, `<leader>gdc` closes it, `<leader>gdr` refreshes, `<leader>gdt` toggles the file panel, `<leader>gdf` opens file history for the current file, and `<leader>gdp` opens project-wide file history.

#### Scenario: Open and close a diff view
- **WHEN** the user presses `<leader>gdd` in a repo with uncommitted changes
- **THEN** a diffview tab opens showing changed files side by side, and `<leader>gdc` closes it

#### Scenario: File history
- **WHEN** the user presses `<leader>gdf` in a tracked file
- **THEN** the file's commit history opens with per-commit diffs

### Requirement: Full git UI via neogit
The configuration SHALL provide a Magit-style git interface via neogit in a floating window, integrated with diffview (for diffs) and telescope (for pickers). Keymaps: `<leader>gn` opens the status buffer, `<leader>gc` opens the commit popup, `<leader>gp` the push popup, `<leader>gP` the pull popup.

#### Scenario: Stage and commit from the status buffer
- **WHEN** the user presses `<leader>gn`, stages a file with `s`, and presses `c`
- **THEN** the commit popup opens and completing it creates the commit

#### Scenario: Push popup
- **WHEN** the user presses `<leader>gp`
- **THEN** neogit opens directly on the push popup

### Requirement: GitHub PR and issue workflows via octo.nvim
The configuration SHALL provide GitHub pull-request and issue management inside Neovim via octo.nvim with the telescope picker and `enable_builtin = true`. The plugin SHALL remain pinned to commit `7566ab21843bf0de721f72891733c0372738d3ee`, with a code comment recording that newer versions are bugged. Octo actions SHALL be mapped under a `<leader>gh` GitHub which-key tree mirroring the old config: issues under `<leader>ghi` (list/create/search/open-by-number/close/reopen/url), pull requests under `<leader>ghp` (list/create/search/open-by-number/close/merge/reload/url/ready/draft/checks), reviews under `<leader>ghr` (start/resume/commit/discard/submit/comments), comments under `<leader>ghc` (add/delete), reactions under `<leader>ghR`, assignees/labels under `<leader>gha`/`<leader>ghl`, reviewers under `<leader>ghv`, and `<leader>ghn`/`<leader>ghs`/`<leader>ghd` for notifications/search/discussions.

#### Scenario: List pull requests
- **WHEN** the user presses `<leader>ghpl` (or runs `:Octo pr list`) in a repo with a GitHub remote and an authenticated `gh` CLI
- **THEN** a telescope picker lists the repository's pull requests

#### Scenario: Open an issue by number
- **WHEN** the user presses `<leader>ghio` and enters an issue number at the prompt
- **THEN** that issue opens in an Octo buffer

#### Scenario: Pin survives plugin updates
- **WHEN** `vim.pack.update()` runs
- **THEN** octo.nvim stays at the pinned commit

### Requirement: Merge conflict resolution via git-conflict.nvim
The configuration SHALL highlight merge conflict regions and provide resolution mappings under `<leader>gC`: `<leader>gCo` choose ours, `<leader>gCt` choose theirs, `<leader>gCb` choose both, `<leader>gC0` choose none, `<leader>gCn`/`<leader>gCp` jump to next/previous conflict, `<leader>gCQ` list conflicts in quickfix, and `<leader>gCq` list conflicts in Trouble.

#### Scenario: Resolve a conflict hunk
- **WHEN** a buffer contains conflict markers and the cursor is inside a conflict
- **THEN** `<leader>gCo` keeps the current branch's side and removes the markers

#### Scenario: Navigate conflicts
- **WHEN** a buffer contains multiple conflicts
- **THEN** `<leader>gCn` and `<leader>gCp` cycle the cursor through them

## MODIFIED Requirements

### Requirement: In-buffer git via gitsigns
The configuration SHALL show git hunk signs, current-line blame (toggleable), and provide hunk actions (stage, reset, preview, next/prev) via gitsigns.nvim keymaps under a `<leader>g` which-key group. To leave `<leader>gd` to the diffview group, `<leader>gp` to neogit push, and the `<leader>gh` prefix to the GitHub/Octo tree, diff-against-index SHALL be mapped to `<leader>gD` and preview-hunk to `<leader>gv`.

#### Scenario: Hunk navigation and stage
- **WHEN** a tracked file has unstaged modifications
- **THEN** hunk signs render and `]h`/`[h` navigate hunks and the stage keymap stages the hunk under the cursor

#### Scenario: Relocated keymaps
- **WHEN** the user presses `<leader>gv` on a modified hunk or `<leader>gD` in a modified buffer
- **THEN** the hunk preview float opens, and the buffer diffs against the index, respectively
