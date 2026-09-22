# git-integration Specification

## Purpose
Git workflows without leaving Neovim: hunk-level staging and blame in the buffer, a floating lazygit, side-by-side diffs and file history, a full Magit-style status and commit UI, GitHub pull requests and issues, merge-conflict resolution, and the wiring that puts AI-drafted commit messages behind the same `<leader>g` keymaps.

## Requirements

### Requirement: In-buffer git via gitsigns
The configuration SHALL show git hunk signs, current-line blame (toggleable), and provide hunk actions (stage, reset, preview, next/prev) via gitsigns.nvim keymaps under a `<leader>g` which-key group. To leave `<leader>gd` to the diffview group, `<leader>gp` to neogit push, and the `<leader>gh` prefix to the GitHub/Octo tree, diff-against-index SHALL be mapped to `<leader>gD` and preview-hunk to `<leader>gv`.

#### Scenario: Hunk navigation and stage
- **WHEN** a tracked file has unstaged modifications
- **THEN** hunk signs render and `]h`/`[h` navigate hunks and the stage keymap stages the hunk under the cursor

#### Scenario: Relocated keymaps
- **WHEN** the user presses `<leader>gv` on a modified hunk or `<leader>gD` in a modified buffer
- **THEN** the hunk preview float opens, and the buffer diffs against the index, respectively

### Requirement: Lazygit floating terminal
The configuration SHALL open lazygit in a floating terminal window via a keymap (`<leader>gg`), closing the float automatically when lazygit exits, implemented without an extra plugin.

#### Scenario: Open and close lazygit
- **WHEN** the user presses `<leader>gg`
- **THEN** lazygit opens in a centered float in insert/terminal mode, and quitting lazygit closes the float

### Requirement: Commit-message plugin wiring
The configuration SHALL install the `commitsmith` commit-message plugin and configure it, supplying its options and keymaps and providing the fallback callback that routes a commit-message prompt to Sidekick. The commit-message behaviour itself is specified by the `commit-message-ai` capability; this configuration owns only the wiring.

The existing commit keymaps SHALL keep their meaning: `<leader>am` (and buffer-local `<leader>gm` in `gitcommit` buffers) generates a commit message, and `<leader>aM` (and buffer-local `<leader>gM`) opens harness and model selection. The conversation window SHALL be opened with `<leader>ac`, and with a buffer-local `<leader>gc` in `gitcommit` buffers that shadows the neogit commit popup, which is not meaningful inside a commit buffer.

The Sidekick module SHALL NOT contain commit-message generation logic; it SHALL configure Sidekick only.

#### Scenario: Plugin wired with a Sidekick fallback
- **WHEN** the user invokes the generate keymap outside a `gitcommit` buffer
- **THEN** the configured fallback callback sends the commit-message prompt through Sidekick's CLI

#### Scenario: Generate keymaps preserved
- **WHEN** the user presses `<leader>am`, or `<leader>gm` in a `gitcommit` buffer
- **THEN** commit-message generation is triggered as before the extraction

#### Scenario: Settings keymaps preserved
- **WHEN** the user presses `<leader>aM`, or `<leader>gM` in a `gitcommit` buffer
- **THEN** the harness selection flow opens, followed by model selection

#### Scenario: Conversation window keymaps
- **WHEN** the user presses `<leader>gc` in a `gitcommit` buffer
- **THEN** the commit-message conversation window toggles rather than the neogit commit popup

#### Scenario: Sidekick module scope
- **WHEN** the Sidekick configuration module is loaded
- **THEN** it configures Sidekick and its CLI keymaps only, with no commit-generation code

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
