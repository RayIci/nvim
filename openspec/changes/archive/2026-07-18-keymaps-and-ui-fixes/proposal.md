## Why

Daily use of the new config surfaced missing muscle-memory keymaps (carried over from the old dotfiles config) and three real bugs: a duplicated signature-help window during completion, LSP markdown that renders as plain escaped text in hover and blink documentation windows, and a `dap.continue()` configuration chooser that renders inconsistently. All have known fixes — several already proven in `~/dotfiles/.config/nvim`.

## What Changes

- **Keymaps**: `<C-s>` saves in normal+insert mode (insert-mode signature-help map removed; blink's `<C-k>` covers it), `<C-x>` clears search highlight, `<Tab>`/`<S-Tab>` cycle buffers via bufferline, `<leader>xw` closes the current buffer while preserving window layout, `<leader><leader>` opens find-files, `<leader>ff` resumes the last telescope picker.
- **tmux integration**: seamless `<C-h/j/k/l>` navigation between Neovim splits and tmux panes via vim-tmux-navigator.
- **neo-tree**: width increased 32 → 45; `w` opens the selected file through a smart window picker (nvim-window-picker) that only prompts when multiple candidate windows exist.
- **Diagnostics**: a toggle keymap switches diagnostics between refresh-after-insert (current default) and live-while-typing (`update_in_insert`).
- **Signature help fix**: noice's LSP signature handler is disabled so only blink.cmp's signature window appears while completing.
- **Markdown rendering fix**: noice's LSP overrides (`convert_input_to_markdown_lines`, `stylize_markdown`) are dropped in favor of Neovim 0.12's native treesitter-highlighted hover; render-markdown.nvim renders blink documentation/signature buffers (with a re-render-on-scroll autocmd ported from the old config); a markdown-unescape hook fixes pyright's escaped markdown.
- **DAP chooser fix**: telescope-ui-select becomes the `vim.ui.select` provider, making the `dap.continue()` configuration picker (and code actions, etc.) render reliably.
- New plugins: vim-tmux-navigator, nvim-window-picker, render-markdown.nvim, telescope-ui-select.nvim.

## Capabilities

### New Capabilities
- `core-keymaps`: global editor keymaps not owned by any single plugin — save, clear-search, buffer cycle/close, and tmux-aware window navigation.

### Modified Capabilities
- `ui-shell`: neo-tree window width and window-picker open behavior; telescope keymap changes (`<leader><leader>` find-files, `<leader>ff` resume); a `vim.ui.select` provider requirement (telescope-ui-select).
- `lsp-and-diagnostics`: markdown hover requirement changes from noice-rendered to native 0.12 treesitter rendering (plus pyright markdown unescaping); new diagnostics insert-mode refresh toggle; insert-mode signature-help keymap removed.
- `editing-experience`: exactly one signature window during completion; blink documentation/signature windows render formatted markdown, including while cycling candidates.

## Impact

- **Config files**: `lua/config/keymaps.lua`, `lua/config/pack.lua`, `lua/plugins/{lsp,noice,blink,neotree,telescope,bufferline,whichkey}.lua`; new `lua/plugins/render-markdown.lua` and a markdown-unescape fix module.
- **Dependencies**: four new plugins via vim.pack (vim-tmux-navigator, nvim-window-picker, render-markdown.nvim, telescope-ui-select.nvim); tmux-side navigator bindings assumed already present in dotfiles.
- **Behavior changes**: `<C-s>` in insert mode no longer opens signature help; `<leader><leader>` no longer opens the buffers picker (still on `<leader>fb`); noice no longer renders LSP hover/signature.
