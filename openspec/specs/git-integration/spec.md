# git-integration Specification

## Purpose
TBD - created by syncing change setup-nvim-config. Update Purpose after archive.

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

### Requirement: Copilot-generated commit messages
The configuration SHALL provide headless commit-message generation when invoked from a `gitcommit` buffer. The command SHALL read the staged diff, run the persisted commit-generation AI CLI in non-interactive mode when supported, and insert the returned Conventional Commits title and structured body into the commit buffer. Generated commit messages SHALL use a single Conventional Commits title line at most 72 characters, followed by a body that starts with a short introductory sentence and includes a `- ` bullet list of concrete changes. A buffer-local keymap SHALL be available in `gitcommit` buffers for this prompt, and no automatic generation SHALL run when a fresh commit buffer opens.

#### Scenario: No automatic message on fresh commit
- **WHEN** the user runs `git commit` with staged changes and the commit buffer opens empty
- **THEN** no AI-generated message is inserted automatically

#### Scenario: Amend untouched
- **WHEN** the user runs `git commit --amend` and the buffer opens with the previous message
- **THEN** no automatic generation happens

#### Scenario: Manual commit-buffer generation
- **WHEN** the user presses the generate keymap in a commit buffer
- **THEN** the configuration runs the persisted commit-generation AI CLI non-interactively with the staged diff
- **AND** a persistent spinner notification shows the tool and configured model while generation is running
- **AND** the generated commit message is inserted into the commit buffer

#### Scenario: Structured commit body
- **WHEN** a commit-message prompt is rendered for interactive or headless generation
- **THEN** it instructs the AI CLI to write a body with a short introductory sentence
- **AND** it requires a `- ` bullet list of concrete changes
- **AND** it allows a final rationale, impact, or context paragraph only when useful
- **AND** it preserves raw-output constraints such as no code fences, quotes, markdown headings, explanations, commentary, or alternative options

#### Scenario: Commit prompt outside commit buffer
- **WHEN** the user invokes the commit-message keymap outside a `gitcommit` buffer
- **THEN** Sidekick keeps the normal interactive CLI behavior
- **AND** the commit-message prompt is sent through normal Sidekick CLI behavior

### Requirement: Commit-generation CLI and model settings
The configuration SHALL let the user choose and persist the AI CLI and model used for headless commit-message generation. The supported CLI choices SHALL include `copilot` and `claude`. The model choices SHALL be scoped to the selected CLI, SHALL include a default/automatic option when appropriate, and SHALL be changeable from Neovim after initial selection.

#### Scenario: Choose commit-generation CLI
- **WHEN** the user invokes the commit-generation settings command or keymap
- **THEN** the configuration presents supported CLI choices including `copilot` and `claude`
- **AND** the selected CLI is stored for future headless commit-message generation

#### Scenario: Choose model for selected CLI
- **WHEN** the user chooses a commit-generation CLI
- **THEN** the configuration presents only model choices supported by that CLI
- **AND** selecting a model stores it with the selected CLI

#### Scenario: Persist settings across sessions
- **WHEN** the user restarts Neovim after choosing a commit-generation CLI and model
- **THEN** the configuration uses the persisted CLI and model for the next headless commit-message generation
- **AND** the user does not need to reselect them unless they choose to change settings

#### Scenario: Change settings from Neovim
- **WHEN** the user invokes the commit-generation settings command or keymap again
- **THEN** the configuration allows choosing a different supported CLI and model
- **AND** future headless commit-message generations use the updated settings

#### Scenario: Concrete model flag
- **WHEN** the persisted model is a concrete model ID rather than an automatic/default option
- **THEN** the headless command passes the model to the selected CLI using that CLI's supported model flag
- **AND** when the persisted model is automatic/default, the command omits a concrete model flag and lets the CLI decide

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
