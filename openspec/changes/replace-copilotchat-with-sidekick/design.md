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

## Risks / Trade-offs

- [Risk] Sidekick changes the UX from native chat buffer to CLI terminal. → Mitigation: keep keymaps under the same `<leader>a` namespace and provide prompt helpers so daily actions remain one keypress.
- [Risk] Headless commit generation depends on the default CLI supporting non-interactive prompt mode. → Mitigation: support Copilot CLI and Claude CLI explicitly, and fall back to normal Sidekick prompting for unsupported tools.
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
7. Keep `copilot.lua` unchanged and leave Sidekick NES disabled by default.
8. Validate startup and basic Sidekick command loading.

Rollback is straightforward: restore the CopilotChat plugin/module/keymaps and remove Sidekick/default-CLI config.

## Open Questions

- Should the first implementation include explicit `claude` and `copilot` quick-toggle keymaps in addition to Sidekick's selector?
- After the interactive workflow is tested, should commit-message generation regain automatic buffer insertion through a dedicated CLI-backed command?
