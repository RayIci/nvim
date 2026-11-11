# Design

## Context

`lua/plugins/snacks.lua` enables only `notifier`. Telescope is set up in `lua/plugins/telescope.lua` and called directly from `lua/plugins/lsp.lua` (`telescope.builtin` for `gO`, diagnostics and calls), `lua/plugins/noice.lua` (`Noice telescope`), `lua/plugins/todo-comments.lua` (`TodoTelescope`), `lua/plugins/octo.lua` (`picker = "telescope"`), `lua/plugins/auto-session.lua` (session lens) and `lua/langs/python.lua` (venv-selector `picker = "telescope"` plus a result callback). lspsaga provides only `goto_definition`, `goto_type_definition`, `finder ref`/`imp`/default and `code_action`. Neovim 0.12.6 ships an experimental message UI, `vim._core.ui2`: no hit-enter prompts, a pager window, cmdline highlighting.

## Goals / Non-Goals

**Goals:**
- Every key keeps its lhs and meaning (see the specs). Only the window it opens looks different.
- No telescope, noice, lspsaga, illuminate or indent-blankline code left in the configuration.

**Non-Goals:**
- The file explorer (`move-explorer-to-snacks`), folding, breadcrumbs and linting (`trim-editor-hooks`).
- Restyling pickers beyond the default snacks layout.

## Decisions

- **One snacks setup owns picker, input, words, indent and notifier** in `lua/plugins/snacks.lua`, which also defines the `<leader>f*` keys previously in `telescope.lua`. `picker.ui_select = true` replaces telescope-ui-select. The snacks select formatter already appends `[client]` to code actions, which keeps lspsaga's `show_server_name`.
- **Ignore rules as globs.** Telescope's Lua patterns become snacks `exclude` globs. Find-files: `node_modules`, `dist`, `build`, `.git`, `vendor`. Grep adds: `*.lock`, image, font, archive and binary extensions. `hidden = true` for both.
- **Native jumps first, picker when needed.** `gd`, `grt` and `gD` use `Snacks.picker.lsp_definitions`, `lsp_type_definitions` and `lsp_declarations`, which jump directly when there is one result (lspsaga's behaviour). `grr` and `gri` use `lsp_references` and `lsp_implementations`. `<leader>lf` uses a combined picker: `Snacks.picker({ multi = { "lsp_references", "lsp_implementations" } })`, the mechanism snacks' own `smart` source uses, and each item's source names its kind. `gra` and `<leader>la` call `vim.lsp.buf.code_action()`.
- **Built-in message UI instead of noice.** `require("vim._core.ui2").enable({})` runs in `config/options.lua` behind `pcall` and a `prefs.get("ui2", true)` check. That replaces noice's bottom cmdline, `long_message_to_split` and the exit-prompt `ui_attach` hack in one native call. Alternative: plain legacy messages. Rejected, because long messages would block on "Press ENTER" again. The pref is the escape hatch if the experimental UI misbehaves; it is documented in the README rather than given a key.
- **Notifications:** `<leader>fn` → `Snacks.picker.notifications()`, `<leader>un` → `Snacks.notifier.hide()`.
- **Reference highlighting:** `snacks.words` (LSP `documentHighlight`, debounced) replaces illuminate's three providers. `]]`/`[[` map to `Snacks.words.jump(±vim.v.count1, true)`. Treesitter and regex fallbacks are dropped on purpose: they ran on every cursor move in every buffer, including ones with no server.
- **Indent guides:** `snacks.indent` with `char = "│"`, scope enabled, and a `filter` excluding `help`, the explorer, `Trouble`, `trouble` and `mason` (the old ibl exclude list).
- **Integrations:** octo `picker = "snacks"` (the pinned commit ships `lua/octo/pickers/snacks`), auto-session `session_lens.picker = "snacks"`, venv-selector `picker = "snacks"` (its newline-stripping callback is telescope-specific and goes), todo-comments `Snacks.picker.todo_comments()`.
- **vale.nvim** gets the missing snacks groups (picker list, input, preview, match, selection, words, indent scope) in `lua/vale/integrations/snacks.lua`, on a feature branch of that repository. The configuration loads the local checkout while the branch is open (see tasks).

## Risks / Trade-offs

- [`vim._core.ui2` is experimental and may change in a Neovim update] → It is wrapped in `pcall`, can be turned off with one pref, and the configuration never calls its internals.
- [Losing illuminate's regex fallback in server-less buffers] → Accepted: it is the per-keystroke work this rewrite is removing. `*`/`#` still work everywhere.
- [snacks picker keys differ inside the picker from telescope's] → Insert-mode `<C-n>`/`<C-p>`/`<CR>`/`<Esc>` behave the same. Differences are documented in the README.
