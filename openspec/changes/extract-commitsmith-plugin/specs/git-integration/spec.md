## ADDED Requirements

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

## REMOVED Requirements

### Requirement: Copilot-generated commit messages
**Reason**: Replaced by the `commit-message-ai` capability, which owns headless generation for three harnesses plus the refinement conversation. Keeping it here would tie plugin behaviour to this configuration and make the plugin's eventual move to its own repository a spec rewrite.
**Migration**: The behaviour is preserved and extended by `commit-message-ai`'s "Headless commit-message generation" requirement; the wiring that remains this configuration's responsibility is covered by "Commit-message plugin wiring".

### Requirement: Commit-generation CLI and model settings
**Reason**: Replaced by the `commit-message-ai` capability's "Harness selection and persistence" requirement, which adds `codex`, moves storage into the plugin, and makes settings genuinely shared across concurrent Neovim instances.
**Migration**: The persisted `sidekick_commit_generation` preference is read once to seed the plugin's own settings file, so an existing selection survives the extraction.
