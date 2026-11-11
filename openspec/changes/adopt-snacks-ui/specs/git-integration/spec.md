# Spec Delta

## MODIFIED Requirements

### Requirement: GitHub PR and issue workflows via octo.nvim
The configuration SHALL provide GitHub pull-request and issue management inside Neovim via octo.nvim with the snacks picker and `enable_builtin = true`. The plugin SHALL remain pinned to commit `7566ab21843bf0de721f72891733c0372738d3ee`, with a code comment recording that newer versions are bugged.

#### Scenario: List pull requests
- **WHEN** the user presses `<leader>ghpl` (or runs `:Octo pr list`) in a repo with a GitHub remote and an authenticated `gh` CLI
- **THEN** a picker lists the repository's pull requests

#### Scenario: Pin survives plugin updates
- **WHEN** `vim.pack.update()` runs
- **THEN** octo.nvim stays at the pinned commit
