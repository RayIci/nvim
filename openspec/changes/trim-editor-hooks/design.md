# Design

## Context

- **Folding:** `lua/plugins/folding.lua` drives nvim-ufo with a provider chain (lsp → treesitter → indent) and remaps `zR`/`zM`/`zr`/`zm` to ufo functions that keep `foldlevel` high. `lua/plugins/lsp.lua` adds the `foldingRange` capability for ufo.
- **Breadcrumbs:** barbecue attaches navic on LspAttach and updates a winbar on CursorMoved, with a scheduled winbar-clear autocmd for terminals and excluded filetypes.
- **Linting:** `lua/plugins/lint.lua` runs `try_lint` on FileType, BufWritePost and InsertLeave, plus debounced TextChanged/TextChangedI while the `diagnostics_live` pref is on. `lua/langs/python.lua` lints with `ruff` and `mypy` while also enabling the ruff server.
- **Toggles:**
  - inlay hints (`<leader>li`) are not persisted;
  - code lenses use `vim.g.codelens_enabled`, which rides session files, so the setting is per project;
  - rainbow already uses `config.prefs`;
  - the lightbulb has no toggle.
- **`]t`/`[t`:** `lua/plugins/neotest.lua` maps them first, and `lua/plugins/todo-comments.lua` remaps them later, so todo-comments wins.

## Goals / Non-Goals

**Goals:**
- No plugin-driven work on CursorMoved or TextChanged for folding and breadcrumbs beyond what the statusline already redraws.
- No linter starts for an unchanged buffer.

**Non-Goals:**
- Changing which linters each language uses, apart from the duplicate ruff.
- Fold preview (ufo's peek), which was never mapped.

## Decisions

- **Native folds, chosen per buffer:**
  - globally: `foldmethod = "expr"` and `foldtext = ""` (0.12 renders the highlighted first line);
  - when treesitter starts in `plugins/treesitter.lua` (where it already calls `vim.treesitter.start`): `foldexpr = "v:lua.vim.treesitter.foldexpr()"`;
  - on LspAttach, when the client supports `textDocument/foldingRange`: `foldexpr = "v:lua.vim.lsp.foldexpr()"`, so LSP ranges win;
  - when a buffer has neither, `foldmethod = "indent"`;
  - `foldlevelstart = 99` keeps files open, and `zU` moves unchanged into a new `lua/config/folds.lua`.

  Alternative: keep ufo. Rejected, because the provider chain is what 0.12 now does natively, and ufo requests ranges on every change.
- **Breadcrumbs via navic in lualine.** navic attaches on LspAttach for clients with `documentSymbolProvider` (`navic.attach(client, buf)`) with `lazy_update_context = true`, so it updates on CursorHold rather than CursorMoved. A lualine `lualine_c` component shows `navic.get_location()` when `navic.is_available()` and the `breadcrumbs` pref is on. Because the statusline is global (`laststatus = 3`), it naturally shows only the current window. Alternative: dropbar or a native winbar. Rejected: the user chose the statusline.
- **Lint triggers with a changedtick guard.** Each buffer records `vim.b.lint_tick = changedtick` after it is linted. FileType and BufWritePost always lint. BufEnter and InsertLeave lint only when `changedtick ~= lint_tick`. `:checktime` reloads bump changedtick, so an external edit is linted on the next entry. The TextChanged path and its timer are deleted. `<leader>ud` only flips `vim.diagnostic.config({ update_in_insert })`.
- **Duplicate ruff removed** from `linters.python` (now `{ "mypy" }`). The ruff server already publishes the same rule set and supplies code actions.
- **Persisted toggles through `config.prefs`:**
  - keys `lightbulb` (default true), `inlay_hints` (false), `codelens` (true), `breadcrumbs` (true);
  - the lightbulb's `autocmd.enabled` follows the pref, and toggling clears signs in every buffer;
  - on LspAttach, inlay hints and code lenses are enabled from the prefs;
  - toggles apply to all buffers at once;
  - the buffer-local `<leader>ci` inlay toggle stays as it is, unpersisted.
- **`]t`/`[t`:** removed from `plugins/neotest.lua`. The `<leader>tnn`/`<leader>tnp` and `]T`/`[T` maps stay.

## Risks / Trade-offs

- [`foldmethod=expr` with LSP ranges recomputes on server refresh] → Neovim's LSP fold provider caches ranges per buffer and refreshes on `textDocument/didChange` responses, which is the same traffic ufo generated, minus ufo's own work.
- [Breadcrumbs update on CursorHold instead of every move] → A 250 ms `updatetime` lag, judged acceptable for a statusline label.
- [A linter that depends on other files (mypy) is not re-run when only another buffer changed] → Saving any file re-lints that file. Re-entering an unchanged buffer does not, which is the waste this removes. `:lua require("lint").try_lint()` remains available.
