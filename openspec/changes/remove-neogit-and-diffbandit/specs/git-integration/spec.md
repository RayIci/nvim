# Spec Delta

## ADDED Requirements

### Requirement: Managed worktree keymaps
The configuration SHALL provide worktree switching on `<leader>gww`, creation on `<leader>gwc`, and deletion on `<leader>gwd`, with descriptions under a `<leader>gw` which-key group. Existing unrelated Git bindings SHALL retain their behavior.

#### Scenario: Discover worktree actions
- **WHEN** the user opens the `<leader>gw` group
- **THEN** described switch, create, and delete actions are available

#### Scenario: Include all registered checkouts
- **WHEN** the user opens the worktree selector in a repository with a main checkout, linked branches, and a detached linked checkout
- **THEN** the selector identifies the registered checkouts by path and branch or detached status, without omitting the detached checkout

#### Scenario: Preserve existing Git controls
- **WHEN** the user invokes an existing stage, blame, diff, lazygit, or GitHub binding
- **THEN** it retains its existing behavior

## MODIFIED Requirements

### Requirement: In-buffer git via gitsigns
The configuration SHALL show git hunk signs, current-line blame (toggleable), and provide hunk actions (stage, reset, preview, next/prev) via gitsigns.nvim keymaps under a `<leader>g` which-key group. To leave `<leader>gd` to the diffview group and the `<leader>gh` prefix to the GitHub/Octo tree, diff-against-index SHALL be mapped to `<leader>gD` and preview-hunk to `<leader>gv`.

#### Scenario: Hunk navigation and stage
- **WHEN** a tracked file has unstaged modifications
- **THEN** hunk signs render and `]h`/`[h` navigate hunks and the stage keymap stages the hunk under the cursor

#### Scenario: Relocated keymaps
- **WHEN** the user presses `<leader>gv` on a modified hunk or `<leader>gD` in a modified buffer
- **THEN** the hunk preview float opens, and the buffer diffs against the index, respectively

### Requirement: Commit-message keymaps
The existing commit keymaps SHALL keep their meaning: `<leader>am` (and buffer-local `<leader>gm` in `gitcommit` buffers) generates a commit message, and `<leader>aM` (and buffer-local `<leader>gM`) opens harness and model selection. The conversation window SHALL be opened with `<leader>ac`, and with a buffer-local `<leader>gc` in `gitcommit` buffers.

#### Scenario: Generate keymaps preserved
- **WHEN** the user presses `<leader>am`, or `<leader>gm` in a `gitcommit` buffer
- **THEN** commit-message generation is triggered as before the extraction

#### Scenario: Settings keymaps preserved
- **WHEN** the user presses `<leader>aM`, or `<leader>gM` in a `gitcommit` buffer
- **THEN** the harness selection flow opens, followed by model selection

#### Scenario: Conversation window keymaps
- **WHEN** the user presses `<leader>gc` in a `gitcommit` buffer
- **THEN** the commit-message conversation window toggles

#### Scenario: No global commit popup
- **WHEN** the user presses `<leader>gc` outside a `gitcommit` buffer
- **THEN** no git commit popup opens

## REMOVED Requirements

### Requirement: Full git UI via neogit
**Reason**: lazygit is the git UI in use. Neogit duplicated it and kept integration code alive in git-worktree, the workspace tests and the theme.
**Migration**: Use lazygit: `<leader>gg` for status, staging, commit, push and pull; `<leader>gl` for the log. `<leader>gn`, `<leader>gc`, `<leader>gp` and `<leader>gP` are no longer mapped outside `gitcommit` buffers.

### Requirement: Managed worktree actions
**Reason**: Its Neogit status-buffer `w` entry point goes with neogit. The leader keymaps are unchanged and restated as "Managed worktree keymaps".
**Migration**: Use `<leader>gww`, `<leader>gwc` and `<leader>gwd`.
