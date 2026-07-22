## 1. Dependencies and Module Wiring

- [x] 1.1 Add `kevinhwang91/promise-async`, `kevinhwang91/nvim-ufo`, `kosayoda/nvim-lightbulb`, and `nvimdev/lspsaga.nvim` to `lua/config/pack.lua`.
- [x] 1.2 Add focused plugin setup modules for folding, lightbulb, and lspsaga under `lua/plugins/`.
- [x] 1.3 Require the new setup modules from `lua/plugins/init.lua` in an order compatible with existing LSP, Tree-sitter, and UI setup.

## 2. Smart Folding

- [x] 2.1 Configure fold options so folds are enabled, the fold column is visible, and buffers open with folds expanded by default.
- [x] 2.2 Add LSP `textDocument.foldingRange` capability globally alongside blink.cmp capabilities.
- [x] 2.3 Configure nvim-ufo provider selection to prefer LSP folds and fall back to Tree-sitter and indent folds.
- [x] 2.4 Map provider-safe fold commands such as `zR` and `zM`, and include `zr`/`zm` if useful for the chosen UFO behavior.

## 3. LSP UI and Code Actions

- [x] 3.1 Configure nvim-lightbulb as a sign-only code-action indicator that aggregates all attached code-action-capable LSP clients.
- [x] 3.2 Configure lspsaga without adopting breadcrumbs, outline, diagnostics, hover, rename, terminal, implementation signs, or lightbulb.
- [x] 3.3 Replace the existing `gd`, `grr`, `gri`, `grt`, `gra`, and `<leader>la` LSP mappings with lspsaga-backed behavior.
- [x] 3.4 Add `<leader>lf` for lspsaga finder and ensure the `<leader>l` which-key tree remains discoverable.
- [x] 3.5 Preserve existing hover, rename, diagnostics, workspace folder, call hierarchy, inlay hint, codelens, Trouble outline, and breadcrumb behavior outside the selected lspsaga mappings.

## 4. Trouble and CopilotChat

- [x] 4.1 Configure Trouble's `symbols` mode to open on the right at `size = 0.35` so all symbols keymaps use the larger outline.
- [x] 4.2 Set CopilotChat's default model to `gpt-5-mini` while preserving existing window mappings, full diff display, chat keymaps, and headless commit-message generation.

## 5. Validation

- [x] 5.1 Run the smallest available headless Neovim smoke check to confirm the edited configuration loads without errors.
- [x] 5.2 Verify folding options, UFO commands, and LSP folding capability are configured as specified.
- [x] 5.3 Verify LSP attach mappings include the lspsaga-backed keys and do not map bare `gr` or override built-in `gt`.
- [x] 5.4 Verify Trouble symbols uses 35% width and non-symbol Trouble modes keep their existing layout.
- [x] 5.5 Verify CopilotChat setup includes `model = "gpt-5-mini"`.
