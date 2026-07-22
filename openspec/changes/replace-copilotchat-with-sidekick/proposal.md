## Why

CopilotChat's provider path is unreliable in this environment: GitHub's Copilot token endpoint intermittently returns non-JSON 502 HTML, which causes CopilotChat prompts and headless commit generation to fail with misleading model errors. The user already works comfortably with AI CLI/TUI tools, so replacing CopilotChat with a Sidekick-managed CLI workflow avoids that fragile provider path while preserving in-editor AI assistance.

## What Changes

- Replace `CopilotC-Nvim/CopilotChat.nvim` as the chat/review/explain surface with `folke/sidekick.nvim`.
- Keep `zbirenbaum/copilot.lua` for inline ghost-text completion and existing Copilot auth/status behavior.
- Configure Sidekick primarily for AI CLI usage, initially keeping Copilot NES disabled to avoid changing inline-editing semantics beyond the chat replacement.
- Use Sidekick's default CLI/session behavior for normal AI actions: select, toggle/focus CLI, explain/review selected or current context, diagnostics, and commit-message prompt.
- Preserve visual-selection workflows by sending Sidekick context such as `{selection}` and `{this}` through Sidekick.
- Replace CopilotChat commit-message generation with conditional behavior: from `gitcommit` buffers, run a non-interactive CLI prompt and insert the result; outside `gitcommit` buffers, keep normal Sidekick behavior.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `editing-experience`: Replace CopilotChat chat/model/commit-message requirements with a Sidekick CLI-based AI assistant workflow while preserving Copilot inline completion.
- `git-integration`: Replace automatic CopilotChat commit-message insertion with an interactive Sidekick commit-message prompt for staged changes.

## Impact

- Affected plugin modules: `lua/config/pack.lua`, `lua/plugins/init.lua`, `lua/plugins/copilot-chat.lua` removal/replacement, and a new Sidekick setup module.
- Affected dependencies: remove or stop configuring `CopilotC-Nvim/CopilotChat.nvim`; add `folke/sidekick.nvim`; continue using `folke/snacks.nvim` for picker/notification support.
- Affected keymaps: `<leader>aa`, `<leader>ae`, `<leader>ar`, and commit-message generation mappings move from CopilotChat to Sidekick.
- Affected specs: `openspec/specs/editing-experience/spec.md`.
- Affected specs: `openspec/specs/git-integration/spec.md`.
