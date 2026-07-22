## Context

The configuration currently centralizes plugin installation in `lua/config/pack.lua`, editor defaults in `lua/config/options.lua`, and LSP behavior in `lua/plugins/lsp.lua`. Tree-sitter is already enabled per filetype, Trouble provides symbols and diagnostics panels, barbecue/navic already own breadcrumbs, Telescope backs most LSP pickers, and CopilotChat is configured in `lua/plugins/copilot-chat.lua`.

The requested change touches several related editor experience surfaces, but the common design constraint is to avoid replacing working subsystems wholesale. Each addition should be narrow: smart folding should improve fold quality without closing code on open, the lightbulb should only indicate code-action availability, lspsaga should be used only for selected LSP flows, Trouble should remain the symbols outline provider, and CopilotChat should retain its existing window/keymap behavior while using a fixed lightweight default model.

## Goals / Non-Goals

**Goals:**

- Provide smart folding with LSP ranges when available and robust fallback behavior when they are not.
- Keep all folds open by default on file open while making fold commands and gutter indicators useful.
- Add a code-action indicator that works when multiple LSP clients are attached to the same buffer.
- Adopt lspsaga for definition/reference/implementation/type-definition flows, finder, and code actions only.
- Increase the Trouble symbols window to 35% width consistently.
- Pin CopilotChat to `gpt-5-mini`, which was verified as available in the local Copilot model list.

**Non-Goals:**

- Do not adopt lspsaga breadcrumbs, outline, diagnostics, hover, rename, float terminal, implementation signs, or lightbulb.
- Do not replace barbecue/navic breadcrumbs, Trouble symbols, Telescope diagnostics/call hierarchy, or toggleterm.
- Do not auto-close imports, comments, or all folds on buffer open.
- Do not change Copilot inline completion behavior or commit-message generation semantics beyond inheriting the CopilotChat default model unless explicitly overridden later.

## Decisions

### Use nvim-ufo for smart folding

Use `kevinhwang91/nvim-ufo` with `kevinhwang91/promise-async` instead of relying only on native fold expressions. UFO gives asynchronous fold updates, LSP `foldingRange` support, Tree-sitter and indent fallbacks, modern fold previews, and fold APIs that preserve the high fold level needed to keep folds open by default.

Alternatives considered:

- Native Tree-sitter foldexpr: simpler dependency-wise, but less flexible and does not provide the same LSP-provider/fallback model or preview behavior.
- Indent-only folding: robust but not smart enough for semantic language structures.

Implementation direction:

- Add UFO and its dependency to `vim.pack.add`.
- Add `textDocument.foldingRange = { dynamicRegistration = false, lineFoldingOnly = true }` to global LSP capabilities alongside blink.cmp capabilities.
- Configure `foldcolumn = "1"`, high `foldlevel`/`foldlevelstart`, and enabled folds so files open expanded.
- Use provider selection that prefers LSP folds and falls back to Tree-sitter and indent.
- Map provider-safe fold commands such as `zR`, `zM`, and optionally `zr`/`zm` to UFO APIs.
- Do not configure `close_fold_kinds_for_ft` to auto-close imports/comments in this change.

### Use nvim-lightbulb for the code-action icon

Use `kosayoda/nvim-lightbulb` for a sign-only code-action indicator. Its implementation checks every attached client that supports `textDocument/codeAction` and requests actions through `vim.lsp.buf_request_all`, which directly addresses the multiple-LSP concern.

Alternatives considered:

- Lspsaga lightbulb: convenient if adopting lspsaga broadly, but it couples the indicator to lspsaga and was not selected for the multi-client requirement.
- Custom aggregator: possible, but duplicates a mature focused plugin.

Implementation direction:

- Add the plugin to `vim.pack.add`.
- Configure it as sign-only, with virtual text/float/line/number handlers disabled.
- Enable autocmd updates on cursor-hold style events, excluding plugin panel filetypes as needed.
- Keep actual code-action execution owned by lspsaga mappings selected below.

### Adopt only selected lspsaga modules

Install and configure `nvimdev/lspsaga.nvim`, but only map selected flows: definition, references, implementation, type definition, finder, and code action. Do not replace unrelated UI modules.

Alternatives considered:

- Full lspsaga adoption: would duplicate or replace Trouble symbols, barbecue breadcrumbs, toggleterm, diagnostics, and existing hover behavior.
- No lspsaga adoption: preserves the current setup but misses the richer finder/peek/action UI requested.

Implementation direction:

- Add lspsaga to `vim.pack.add`.
- Add a focused `lua/plugins/lspsaga.lua` setup module and require it from `lua/plugins/init.lua`.
- Replace existing LSP attach mappings:
  - `gd` uses lspsaga definition behavior.
  - `grr` uses lspsaga reference/finder behavior.
  - `gri` uses lspsaga implementation/finder behavior.
  - `grt` uses lspsaga type-definition behavior.
  - `gra` and `<leader>la` use lspsaga code actions.
  - `<leader>lf` opens lspsaga finder.
- Keep the safe `grr`/`gri`/`grt` key shape rather than mapping bare `gr` or `gt`, avoiding conflicts with Neovim's `gr*` family and built-in tab navigation.

### Configure Trouble symbols mode width globally

Set the Trouble `symbols` mode window to a right split with `size = 0.35` in `require("trouble").setup`, rather than only changing individual command-line invocations. This ensures both `<leader>ks` and `<leader>lo` use the same larger outline.

### Set CopilotChat model to gpt-5-mini

Set `model = "gpt-5-mini"` in CopilotChat setup. A local Copilot model inspection returned `gpt-5-mini` as available and enabled. All available models reported the same multiplier, so "cheap" is interpreted as choosing a lightweight mini model rather than a premium-looking flagship model.

Alternatives considered:

- `gpt-5.4-mini`: also lightweight, but not the documented CopilotChat example/default.
- `gemini-3.5-flash` or `claude-haiku-4.5`: also lightweight families, but less aligned with CopilotChat's documented default.
- `auto`: avoids hardcoding, but does not satisfy the request for a fixed cheap model.

## Risks / Trade-offs

- [Risk] Some LSP servers may not support `textDocument/foldingRange` or may return poor folds. Mitigation: configure Tree-sitter and indent fallbacks.
- [Risk] Fold gutters change the visual layout by one column. Mitigation: use a small fold column and keep folds open by default.
- [Risk] Multiple plugins can surface code actions. Mitigation: use nvim-lightbulb only for indication and lspsaga only for action execution.
- [Risk] Lspsaga mappings may diverge from current Telescope picker behavior. Mitigation: scope lspsaga to requested mappings and keep unrelated Telescope/Trouble flows intact.
- [Risk] `gpt-5-mini` availability depends on Copilot account/model policy over time. Mitigation: the model was verified locally during proposal; if unavailable later, `:CopilotChatModels` can be used to choose another enabled model.

## Migration Plan

1. Add the new plugin dependencies to the native `vim.pack.add` list.
2. Add focused setup modules for folding, lightbulb, and lspsaga, following the existing `lua/plugins/*.lua` convention.
3. Update LSP capabilities and keymaps in the existing LSP setup.
4. Update Trouble and CopilotChat setup options.
5. Start Neovim headlessly or with a small smoke command to confirm all configured modules load.
6. Validate representative behavior manually or with targeted headless checks where feasible.

Rollback is straightforward: remove the new setup modules and plugin entries, restore the previous LSP mappings, and remove the Trouble/CopilotChat option changes.

## Open Questions

None for this proposal. Future changes can revisit whether to adopt additional lspsaga modules such as hover or rename.
