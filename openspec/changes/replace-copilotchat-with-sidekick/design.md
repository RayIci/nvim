## Context

The current AI chat workflow is built around CopilotChat.nvim. It owns the `<leader>a*` chat keymaps, the review/explain commands, the configured `gpt-5-mini` default model, and a headless commit-message generator for `gitcommit` buffers.

The observed failure mode is not caused by the user's Copilot inline-completion auth: `copilot.lua` remains online through the Copilot language server and its `auth.db`. CopilotChat uses its own provider/token/model path and can fail when GitHub's Copilot token endpoint returns non-JSON 502 HTML. The user is comfortable using AI CLI/TUI tools directly: Claude CLI at home and Copilot CLI at work.

## Goals / Non-Goals

**Goals:**

- Replace CopilotChat as the AI chat/review/explain interface with Sidekick's AI CLI integration.
- Keep `copilot.lua` inline ghost-text completion unchanged.
- Use Sidekick's default CLI/session selection behavior for normal AI actions.
- Preserve visual-selection workflows for explain/review/fix prompts.
- Keep the `<leader>a` key namespace as the AI command tree.
- Keep normal Sidekick prompts interactive, while making commit-message generation auto-insert only from `gitcommit` buffers.
- Let the user configure the headless commit-message CLI and model from Neovim, and persist those choices across Neovim sessions.

**Non-Goals:**

- Do not replace `copilot.lua` inline suggestions.
- Do not depend on CopilotChat.nvim's provider, model list, or token cache.
- Do not initially enable Sidekick NES by default; it can be explored separately after the CLI workflow is stable.
- Do not auto-generate commit messages when a `gitcommit` buffer opens; generation remains explicitly keymap-driven.

## Decisions

### Use Sidekick as the AI assistant surface

Install and configure `folke/sidekick.nvim` for its CLI integration instead of another API-backed chat plugin. Sidekick can wrap Claude, Copilot CLI, OpenCode, Codex, Gemini, and other tools, and it includes context-aware prompt rendering, prompt selection, file watching, and session attachment.

Alternatives considered:

- **CodeCompanion.nvim**: closer to CopilotChat's native chat-buffer UX and very capable, but if configured with Copilot it may still depend on the same GitHub Copilot backend path. It is a good future option if the user wants a Neovim-native chat buffer again.
- **Avante.nvim**: powerful and agentic, but heavier and more invasive than needed for replacing chat/review/explain commands.
- **gp.nvim**: simpler, but less aligned with the user's CLI/TUI workflow and Sidekick's context/session tooling.

### Keep Copilot inline completion separate

Keep `zbirenbaum/copilot.lua` as the source of inline ghost-text suggestions. Sidekick's NES feature remains disabled by default to avoid changing editing behavior while replacing the chat workflow.

This keeps the migration focused: chat/review/explain move to Sidekick, while completion remains stable.

### Use Sidekick's native CLI/session behavior

Sidekick's native `:Sidekick cli select` attaches to a selected CLI session and `:Sidekick cli toggle`, `focus`, `prompt`, and `send` already know how to target active sessions. Normal AI keymaps should call those Sidekick APIs directly instead of wrapping them in a custom default-session layer.

Proposed behavior:

- `<leader>as` calls Sidekick's CLI selector.
- `<leader>aa` calls Sidekick's CLI toggle.
- Prompt keymaps use Sidekick's native `send`/`prompt` behavior.
- Sidekick decides whether to attach an existing session, start a new session, or show a selector.

This keeps home/work behavior aligned with the user's actual Sidekick selection: choose `claude` at home or `copilot` at work through the normal Sidekick picker.

Sidekick mux integration should prefer tmux when it is installed and fall back to the normal terminal backend otherwise. The wrapper keeps `create = "terminal"` so the Sidekick window remains inside Neovim while the underlying CLI session persists through tmux.

### Keep Sidekick interactive except for gitcommit commit generation

The current CopilotChat commit generator auto-runs in empty `gitcommit` buffers and inserts the generated message into the buffer. Sidekick is centered on CLI sessions, so normal AI actions should stay interactive and use Sidekick's native prompt routing.

Commit-message generation is the exception when invoked from a `gitcommit` buffer: it should run the selected or active Sidekick CLI tool in non-interactive mode, include the staged diff directly in the prompt, and insert the returned message into the commit buffer. When the same commit-message keymap is invoked outside a `gitcommit` buffer, it should keep normal Sidekick behavior and send the commit prompt to Sidekick.

### Persist dedicated commit-generation CLI and model preferences

Headless commit-message generation should have its own persisted settings instead of relying only on the currently attached Sidekick session. Normal Sidekick chat/session behavior remains native, but the commit generator needs deterministic headless execution.

Proposed behavior:

- A Neovim command/keymap opens a settings picker for commit generation.
- The user first chooses the CLI tool from supported headless tools: `copilot` or `claude`.
- The model picker then shows only models supported by the selected CLI, including an `auto`/default option when the CLI supports choosing automatically.
- The chosen CLI and model persist via the existing preference-storage pattern so they survive Neovim restarts and work across sessions.
- The commit generator uses the persisted CLI/model by default, while still falling back to prompting when no supported tool is installed or configured.
- The spinner/status message shows the persisted CLI/model that will be used.

This differs from normal Sidekick selection intentionally: normal AI actions continue to use Sidekick's own selector and session attachment, while commit-message generation uses the stored headless tool settings because it inserts directly into the commit buffer.

## Risks / Trade-offs

- [Risk] Sidekick changes the UX from native chat buffer to CLI terminal. → Mitigation: keep keymaps under the same `<leader>a` namespace and provide prompt helpers so daily actions remain one keypress.
- [Risk] Headless commit generation depends on the default CLI supporting non-interactive prompt mode. → Mitigation: support Copilot CLI and Claude CLI explicitly, and fall back to normal Sidekick prompting for unsupported tools.
- [Risk] Model names and CLI flags can drift as AI CLIs evolve. → Mitigation: keep model lists small and explicit per CLI, include an automatic/default option, and pass model flags only when a concrete model is selected.
- [Risk] Claude/Copilot CLI availability differs between machines. → Mitigation: Sidekick's selector shows installed/missing tools and can open install URLs.
- [Risk] Sidekick NES overlaps with existing Copilot inline suggestions. → Mitigation: disable NES by default in this change.
- [Risk] Removing CopilotChat removes its model picker and native prompt commands. → Mitigation: Sidekick prompt library and custom prompts cover explain/review/fix/diagnostics/commit flows.

## Migration Plan

1. Add `folke/sidekick.nvim` to the plugin list and lockfile.
2. Replace the CopilotChat setup module with a Sidekick setup module.
3. Remove CopilotChat keymaps and gitcommit autocmds.
4. Add `<leader>a` keymaps for Sidekick actions using Sidekick's native CLI API.
5. Configure Sidekick CLI window/layout, prompt set, file watching, and Snacks picker usage.
6. Add commit-buffer-only headless generation that inserts CLI output into the commit buffer.
7. Add persisted commit-generation settings for CLI/model selection and expose them through Neovim commands/keymaps.
8. Keep `copilot.lua` unchanged and leave Sidekick NES disabled by default.
9. Validate startup and basic Sidekick command loading.

Rollback is straightforward: restore the CopilotChat plugin/module/keymaps and remove Sidekick/default-CLI config.

## Open Questions

- Which exact Copilot and Claude model IDs should be listed initially beyond the default/auto choice?
