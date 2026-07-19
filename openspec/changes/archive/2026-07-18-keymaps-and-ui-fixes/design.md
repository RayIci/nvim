## Context

The Neovim 0.12 config (native vim.pack, blink.cmp, noice, telescope, nvim-dap) works but has UX gaps and three concrete bugs, all diagnosed:

1. **Double signature window**: signature help is enabled in both blink.cmp (`plugins/blink.lua`) and noice (`plugins/noice.lua`), so both open a float on the same trigger.
2. **Broken markdown rendering**: noice overrides `vim.lsp.util.convert_input_to_markdown_lines` / `stylize_markdown`, but on 0.11+ `vim.lsp.buf.hover()` no longer routes through those functions — and our `H` keymap calls it directly. blink renders its own docs buffer, which noice's override can interfere with; scrolling candidates shows raw markdown.
3. **Flaky DAP config chooser**: no `vim.ui.select` provider is installed, so `dap.continue()` falls back to cmdline `inputlist`, which renders inconsistently under noice's cmdline popup.

The prior config at `~/dotfiles/.config/nvim` (read-only reference, do not modify) contains proven solutions: render-markdown.nvim with blink filetype integration and re-render-on-scroll autocmd (`lua/mnvim/plugins/ui/render-markdown.lua`), a pyright markdown-unescape hook (`lua/fixes/lsp-markdown-unescape.lua`), a smart window-picker open for neo-tree (`lua/mnvim/plugins/ui/neotree.lua`), telescope-ui-select, and vim-tmux-navigator.

User decisions already made: `<C-s>` saves everywhere and the insert-mode signature-help map is dropped (blink's `<C-k>` covers it); neo-tree width 45; markdown fix = render-markdown.nvim + drop noice LSP overrides (not the old config's noice-on-top approach).

## Goals / Non-Goals

**Goals:**
- Restore muscle-memory keymaps from the old config (save, clear search, buffer cycle/close, tmux navigation, picker maps).
- Exactly one signature window during completion.
- Formatted markdown in hover, blink documentation, and blink signature windows — including while cycling candidates, and for pyright's escaped output.
- Deterministic `vim.ui.select` UI (fixes the DAP chooser and improves code actions).
- neo-tree: wider window, `w` opens via smart window picker.
- Toggle for diagnostics refresh timing (`update_in_insert`).

**Non-Goals:**
- No changes to `~/dotfiles/.config/nvim` (reference only).
- No bufferline pinning/close-all helpers from the old config (`<leader>xa`/`<leader>xA`) — only `<leader>xw`.
- No snacks.nvim adoption; the buffer-close helper is implemented inline.
- No tmux.conf changes (assumed already configured for vim-tmux-navigator).
- No lazygit/neo-tree git-refresh autocmds from the old config.

## Decisions

**D1 — tmux navigation via vim-tmux-navigator.** Replace the four `<C-h/j/k/l>` window maps in `config/keymaps.lua` with the plugin's maps (it falls back to Vim window movement when not inside tmux). Alternative considered: smart-splits.nvim (adds resize integration) — rejected to match the existing tmux-side config and keep behavior identical to the old setup.

**D2 — Layout-preserving buffer close, inline.** `<leader>xw` uses a small helper: for each window showing the target buffer, switch it to the alternate/next listed buffer, then `bdelete`. Alternatives: snacks.nvim `bufdelete` (old config) or mini.bufremove — rejected to avoid a new dependency for one function. Lives in `config/keymaps.lua`. The existing `<leader>bd` plain `bdelete` map is replaced by this helper too. which-key group `<leader>x` renamed "diagnostics/close" (trouble keeps `xx/xb/xq/xl/xs`; `xw` is free).

**D3 — Signature: blink only.** Set noice `lsp.signature.enabled = false` and remove the insert-mode `<C-s>` signature map from `plugins/lsp.lua`. blink's `signature = { enabled = true }` and its `<C-k>` toggle remain the single source. Alternative (disable blink's, keep noice's) rejected: blink's window is completion-context aware and already styled.

**D4 — Markdown pipeline: native hover + render-markdown.nvim.** Remove noice's `lsp.override` block and `hover.enabled`/`signature.enabled` (noice keeps cmdline/messages/notify duties only). Hover (`H`, `vim.lsp.buf.hover` with rounded border) uses 0.12's built-in treesitter markdown rendering. Add render-markdown.nvim configured for `blink-cmp-documentation` and `blink-cmp-signature` filetypes with `completions.blink.enabled = true`, registering those filetypes as markdown for treesitter, plus the ported buffer-attach re-render autocmd (blink reuses one buffer while cycling candidates; render-markdown misses those edits without it). Port the old config's markdown-unescape hook (`convert_input_to_markdown_lines` wrapper + HTML entity decode) as `lua/plugins/lsp-markdown-fix.lua`, trimmed of its lazy.nvim-specific blink hook (vim.pack loads eagerly, so hook blink directly at setup). Alternative (old config as-is: render-markdown on top of noice overrides) rejected — more moving parts and the override is the thing currently breaking hover.

**D5 — `vim.ui.select` via telescope-ui-select.** Add the extension and load it in `plugins/telescope.lua`. Fixes the `dap.continue()` chooser and standardizes every `vim.ui.select` call. Alternatives: dressing.nvim (archived), snacks picker (new dependency) — telescope is already present.

**D6 — neo-tree smart open.** Add nvim-window-picker with `autoselect_one = true` and filter rules excluding neo-tree/notify/terminal/quickfix windows. Port `open_with_smart_picker` (directory → toggle; ≤1 candidate window → plain open; else → `open_with_window_picker`) and map it to `w` and `<cr>`. Width 45.

**D7 — Diagnostics toggle.** `<leader>ud` flips `update_in_insert` via `vim.diagnostic.config()` and notifies the new state. Default stays `false` (refresh after leaving insert).

**D8 — Telescope keymap swap.** `<leader><leader>` → `find_files` (was buffers; buffers stays on `<leader>fb`), `<leader>ff` → `builtin.resume` (was find_files). `<leader>f.` (resume) is removed as redundant.

## Risks / Trade-offs

- [Native hover markdown is plainer than noice's rendering] → Acceptable: 0.12 highlights code fences and conceals markup via treesitter; render-markdown covers the blink windows where the real complaints were.
- [render-markdown re-render autocmd depends on blink's buffer-reuse behavior] → Ported autocmd is defensive (validity checks, pcall, debounce timer); worst case is unrendered markdown, not errors.
- [Unescape hook wraps a private-ish `vim.lsp.util` function that may change on Neovim upgrades] → Wrapper pcalls and degrades to original output; isolated in one file for easy removal.
- [`<Tab>` in normal mode shadows the `<C-i>` jump-forward default in terminals where they're indistinguishable] → Known trade-off the user accepted for years in the old config; `<C-o>`'s counterpart is still reachable via `:jumps`.
- [vim-tmux-navigator requires matching tmux-side bindings] → Already present in dotfiles tmux config; outside tmux the plugin degrades to normal window movement.
- [telescope-ui-select changes the look of every `vim.ui.select` consumer] → Intended; consistent picker UI is the goal.
