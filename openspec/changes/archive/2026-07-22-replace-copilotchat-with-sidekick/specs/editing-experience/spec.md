## ADDED Requirements

### Requirement: Sidekick CLI AI assistant
The configuration SHALL provide an AI assistant workflow through `folke/sidekick.nvim` CLI integration, replacing CopilotChat as the primary chat/review/explain interface. Sidekick SHALL use the `<leader>a` key namespace for selecting, toggling, focusing, and sending prompts to AI CLI tools, and SHALL support at least Claude CLI and Copilot CLI when those tools are installed.

#### Scenario: Select and open AI CLI
- **WHEN** the user invokes the configured AI CLI selection keymap
- **THEN** Sidekick presents available CLI tools and sessions
- **AND** selecting a tool attaches to or starts that CLI inside Neovim

#### Scenario: Toggle AI CLI
- **WHEN** the user invokes the configured AI toggle keymap
- **THEN** Sidekick opens, attaches, toggles, or asks for a CLI session using its native behavior

### Requirement: Native Sidekick CLI session behavior
The configuration SHALL use Sidekick's native CLI/session behavior for normal AI actions. The configuration SHALL NOT add a custom default-session routing layer for normal Sidekick prompts; Sidekick SHALL decide whether to use an active session, attach an existing session, start a new session, or show its selector.

#### Scenario: Sidekick owns session selection
- **WHEN** the user invokes normal AI keymaps such as toggle, explain, review, diagnostics, or prompt picker
- **THEN** those keymaps call Sidekick's native CLI APIs directly
- **AND** Sidekick owns session selection and attachment behavior

#### Scenario: Tmux-backed sessions
- **WHEN** `tmux` is installed and the user starts or attaches a Sidekick CLI
- **THEN** Sidekick uses tmux-backed session persistence
- **AND** if the selected session is already running externally, default AI keymaps attach to and send prompts to that existing session without forcing a new Neovim terminal
- **AND** when `tmux` is unavailable, Sidekick falls back to its terminal backend

### Requirement: Sidekick context prompts
The configuration SHALL map explain, review, diagnostics, and commit-message prompts to Sidekick using context variables such as `{this}`, `{selection}`, `{file}`, and `{diagnostics}`. Visual-mode prompt keymaps SHALL send the selected code as context so the user can ask about a specific range.

#### Scenario: Explain visual selection
- **WHEN** the user visually selects code and invokes the explain keymap
- **THEN** the selected code is sent through Sidekick with an explain prompt

#### Scenario: Review current context
- **WHEN** the user invokes the review keymap from normal mode
- **THEN** Sidekick sends a review prompt using the current file or cursor context

#### Scenario: Commit message prompt
- **WHEN** the user invokes the commit-message prompt keymap
- **THEN** the configuration uses the commit-message behavior appropriate for the current buffer
- **AND** outside `gitcommit` buffers, Sidekick sends the prompt asking a CLI to write a commit message for the staged changes
- **AND** outside `gitcommit` buffers, the result is handled interactively in the CLI session

### Requirement: Sidekick NES disabled by default
The configuration SHALL keep Sidekick's Copilot next-edit suggestions disabled by default so existing `copilot.lua` ghost-text completion semantics remain unchanged.

#### Scenario: Inline completion unchanged
- **WHEN** the user types in insert mode after this change
- **THEN** inline ghost-text suggestions are still provided by `copilot.lua`
- **AND** Sidekick does not introduce additional next-edit suggestions unless explicitly enabled in a later change

## REMOVED Requirements

### Requirement: CopilotChat window behavior
**Reason**: CopilotChat is replaced by Sidekick's CLI-based AI assistant workflow.
**Migration**: Use Sidekick CLI toggle/focus/select keymaps under the `<leader>a` namespace.

### Requirement: CopilotChat default model
**Reason**: Sidekick delegates chat/review/explain prompts to external CLI tools, so CopilotChat's `gpt-5-mini` model setting no longer applies.
**Migration**: Select the desired Sidekick CLI tool, such as `claude` at home or `copilot` at work, and let that CLI manage its own model/auth settings.
