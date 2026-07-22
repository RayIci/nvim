## 1. Dependency and module migration

- [x] 1.1 Add `folke/sidekick.nvim` to `lua/config/pack.lua` and update `nvim-pack-lock.json`.
- [x] 1.2 Remove `CopilotC-Nvim/CopilotChat.nvim` from the active plugin list and stop loading `plugins.copilot-chat`.
- [x] 1.3 Add a new `lua/plugins/sidekick.lua` module and load it from `lua/plugins/init.lua`.
- [x] 1.4 Keep `zbirenbaum/copilot.lua` and the existing Copilot inline completion configuration unchanged.

## 2. Sidekick CLI configuration

- [x] 2.1 Configure Sidekick for CLI terminal usage with Snacks-backed selection UI where supported.
- [x] 2.2 Keep Sidekick NES disabled by default so `copilot.lua` remains the only inline suggestion provider.
- [x] 2.3 Configure Sidekick prompt helpers for explain, review, diagnostics, and commit-message use cases.
- [x] 2.4 Ensure Sidekick supports visual-selection context through `{selection}` or `{this}` prompts.

## 3. Native Sidekick CLI workflow

- [x] 3.1 Use Sidekick's native CLI selector for choosing tools and sessions.
- [x] 3.2 Add keymaps to toggle/open and focus Sidekick through its native CLI API.
- [x] 3.3 Make normal prompt keymaps use Sidekick's native `send` and `prompt` behavior.

## 4. Keymap and behavior replacement

- [x] 4.1 Replace existing CopilotChat `<leader>a*` mappings with Sidekick mappings in the AI namespace.
- [x] 4.2 Replace the CopilotChat review mapping with a Sidekick review prompt for the current file/context or visual selection.
- [x] 4.3 Replace the CopilotChat explain mapping with a Sidekick explain prompt for the current context or visual selection.
- [x] 4.4 Replace CopilotChat commit-message generation with Sidekick-backed commit behavior.
- [x] 4.5 Remove CopilotChat-specific gitcommit autocmds, spinner integration, model configuration, and token/provider assumptions.

## 5. Validation

- [x] 5.1 Run a headless Neovim startup check to verify the Sidekick config loads without CopilotChat.
- [x] 5.2 Verify the configured Sidekick commands/keymaps are registered.
- [x] 5.3 Validate the OpenSpec change artifacts.

## 6. Session and prompt fixes

- [x] 6.1 Remove custom default-session routing for normal Sidekick actions.
- [x] 6.2 Keep direct Sidekick prompt behavior for all normal AI prompts.
- [x] 6.3 Enable tmux-backed Sidekick sessions when `tmux` is installed, falling back to terminal sessions otherwise.

## 7. Commit-buffer auto insertion

- [x] 7.1 Make the commit-message keymap detect `gitcommit` buffers and run headless generation only there.
- [x] 7.2 Insert generated commit messages into the commit buffer while preserving git comment lines.
- [x] 7.3 Keep normal Sidekick prompt behavior for commit-message requests outside `gitcommit` buffers.

## 8. Commit generation status

- [x] 8.1 Show a persistent spinner notification while headless commit generation is running.
- [x] 8.2 Include the selected tool and configured model label in the generation status.

## 9. Commit generation settings

- [x] 9.1 Add persisted preference storage for the headless commit-generation CLI and model.
- [x] 9.2 Add a Neovim command/keymap that lets the user choose `copilot` or `claude` for commit generation.
- [x] 9.3 Add model pickers whose choices are scoped to the selected CLI, including automatic/default options.
- [x] 9.4 Make headless commit generation use the persisted CLI/model instead of only the active Sidekick session.
- [x] 9.5 Pass concrete model IDs to supported CLIs and omit model flags for automatic/default selections.
- [x] 9.6 Document the settings behavior and validate the updated Sidekick configuration.
