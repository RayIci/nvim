## Why

The current Neovim configuration has strong LSP, Tree-sitter, Trouble, and CopilotChat foundations, but several editor interactions still feel less IDE-like than desired: folding is not smart, code actions are discoverable only when manually invoked, LSP navigation lacks the richer lspsaga flows, the Trouble symbols outline is too narrow, and CopilotChat does not pin a lightweight default model.

This change improves those daily-editing surfaces while keeping the existing configuration modular and avoiding a broad replacement of working UI components.

## What Changes

- Add smart folding backed by high-quality fold providers while keeping files fully open by default on buffer entry.
- Show a small fold gutter with open/closed fold indicators and wire fold commands to provider-safe behavior.
- Add a code-action lightbulb indicator that correctly considers all active LSP clients for the current buffer.
- Add lspsaga only for the selected LSP interactions:
  - replace the current definition/reference/implementation/type-definition mappings with lspsaga-backed equivalents,
  - add `<leader>lf` for lspsaga finder,
  - use `<leader>la` for lspsaga code actions.
- Keep lspsaga disabled or unused for breadcrumbs, outline, diagnostics, hover, rename, terminal, and lightbulb unless explicitly added later.
- Increase the Trouble symbols outline width to 35% of the editor width across all symbols entry points.
- Set CopilotChat's default model to `gpt-5-mini`, which is available in the local Copilot model list and is the lightweight model documented by CopilotChat.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `editing-experience`: Add smart folding behavior and pin CopilotChat to the lightweight `gpt-5-mini` default model.
- `lsp-and-diagnostics`: Add multi-client-safe code-action discoverability and replace selected LSP navigation/action mappings with lspsaga-backed flows.
- `ui-shell`: Make the Trouble symbols outline larger by default.

## Impact

- Affected files likely include `lua/config/pack.lua`, `lua/config/options.lua`, `lua/plugins/lsp.lua`, `lua/plugins/trouble.lua`, `lua/plugins/copilot-chat.lua`, `lua/plugins/init.lua`, and new focused plugin modules for folding/lightbulb/lspsaga if that matches existing conventions.
- New plugin dependencies are expected for smart folding (`kevinhwang91/nvim-ufo` plus `kevinhwang91/promise-async`), the code-action lightbulb (`kosayoda/nvim-lightbulb`), and lspsaga (`nvimdev/lspsaga.nvim`).
- LSP global capabilities must include `textDocument.foldingRange` so servers that support folding ranges can participate in smart folding.
- Existing Trouble, barbecue/navic breadcrumbs, Telescope, native diagnostics, toggleterm, and Copilot inline completion behavior should remain intact except where explicitly listed above.
