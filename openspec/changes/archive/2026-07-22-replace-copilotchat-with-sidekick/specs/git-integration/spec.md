## MODIFIED Requirements

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
