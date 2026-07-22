## ADDED Requirements

### Requirement: Smart folding
The configuration SHALL provide smart code folding backed by LSP folding ranges when available, with Tree-sitter and indentation fallbacks for buffers where LSP folding is unavailable or incomplete. Folds SHALL remain open by default when a buffer is opened, and the editor SHALL show a small fold column with open/closed fold indicators.

#### Scenario: File opens expanded
- **WHEN** a source file is opened
- **THEN** fold ranges are available for fold commands
- **AND** the file content is not automatically collapsed

#### Scenario: Folding provider fallback
- **WHEN** the attached LSP does not provide folding ranges for the current buffer
- **THEN** the configuration falls back to Tree-sitter or indentation-based folds instead of disabling folding entirely

#### Scenario: Provider-safe fold commands
- **WHEN** the user invokes the configured open-all or close-all fold command
- **THEN** folds are opened or closed without lowering the high default fold level needed for provider-managed folds

### Requirement: CopilotChat default model
CopilotChat SHALL use `gpt-5-mini` as its configured default model while preserving the existing CopilotChat window behavior, chat keymaps, diff display, and headless commit-message generation flow.

#### Scenario: Chat uses lightweight default
- **WHEN** the user opens CopilotChat or invokes a CopilotChat prompt without specifying another model
- **THEN** CopilotChat uses `gpt-5-mini` as the default model

#### Scenario: Existing chat window behavior remains
- **WHEN** the user presses `<C-c>` in insert mode inside the CopilotChat window
- **THEN** insert mode exits and the chat window remains open
