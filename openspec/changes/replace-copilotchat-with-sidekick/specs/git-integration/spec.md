## MODIFIED Requirements

### Requirement: Copilot-generated commit messages
The configuration SHALL provide headless commit-message generation when invoked from a `gitcommit` buffer. The command SHALL read the staged diff, run the selected or active AI CLI in non-interactive mode when supported, and insert the returned Conventional Commits title and body into the commit buffer. A buffer-local keymap SHALL be available in `gitcommit` buffers for this prompt, and no automatic generation SHALL run when a fresh commit buffer opens.

#### Scenario: No automatic message on fresh commit
- **WHEN** the user runs `git commit` with staged changes and the commit buffer opens empty
- **THEN** no AI-generated message is inserted automatically

#### Scenario: Amend untouched
- **WHEN** the user runs `git commit --amend` and the buffer opens with the previous message
- **THEN** no automatic generation happens

#### Scenario: Manual commit-buffer generation
- **WHEN** the user presses the generate keymap in a commit buffer
- **THEN** the configuration runs the selected or active AI CLI non-interactively with the staged diff
- **AND** a persistent spinner notification shows the tool and configured model while generation is running
- **AND** the generated commit message is inserted into the commit buffer

#### Scenario: Commit prompt outside commit buffer
- **WHEN** the user invokes the commit-message keymap outside a `gitcommit` buffer
- **THEN** Sidekick keeps the normal interactive CLI behavior
- **AND** the commit-message prompt is sent through normal Sidekick CLI behavior
