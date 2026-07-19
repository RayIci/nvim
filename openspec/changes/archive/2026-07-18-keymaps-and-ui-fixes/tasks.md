## 1. Plugins

- [x] 1.1 Add vim-tmux-navigator, nvim-window-picker, render-markdown.nvim, and telescope-ui-select.nvim to `lua/config/pack.lua`

## 2. Core keymaps (`lua/config/keymaps.lua`)

- [x] 2.1 Map `<C-s>` to save in normal and insert mode (insert returns to normal mode)
- [x] 2.2 Map `<C-x>` to `nohlsearch` in normal mode
- [x] 2.3 Map `<Tab>`/`<S-Tab>` to `BufferLineCycleNext`/`BufferLineCyclePrev`
- [x] 2.4 Implement layout-preserving buffer-close helper (windows switch to another listed buffer before `bdelete`; modified buffers refuse with a message) and map it to `<leader>xw`; point `<leader>bd` at the same helper
- [x] 2.5 Remove the four plain `<C-h/j/k/l>` window maps (vim-tmux-navigator provides them) and confirm navigation works in splits both inside and outside tmux
- [x] 2.6 Rename which-key `<leader>x` group to "diagnostics/close" in `lua/plugins/whichkey.lua`

## 3. Signature & markdown rendering

- [x] 3.1 In `lua/plugins/lsp.lua`: remove the insert-mode `<C-s>` signature-help map
- [x] 3.2 In `lua/plugins/noice.lua`: remove the `lsp.override` block and set `hover.enabled = false`, `signature.enabled = false`
- [x] 3.3 Create `lua/plugins/lsp-markdown-fix.lua`: port the unescape/entity-decode hook on `vim.lsp.util.convert_input_to_markdown_lines` from `~/dotfiles/.config/nvim/lua/fixes/lsp-markdown-unescape.lua`, replacing the lazy.nvim `LazyLoad` blink hook with a direct hook at setup; wire it into the plugin loader
- [x] 3.4 Create `lua/plugins/render-markdown.lua`: setup for `markdown`, `blink-cmp-documentation`, `blink-cmp-signature` filetypes with `completions.blink.enabled = true`, treesitter language registration for the blink filetypes, and the ported buffer-attach re-render autocmd (debounced, pcall-guarded)
- [x] 3.5 Verify: hover shows formatted markdown; exactly one signature window while completing; docs stay rendered while cycling candidates; pyright docs show no `\\*` or `&nbsp;`

## 4. Neo-tree (`lua/plugins/neotree.lua`)

- [x] 4.1 Set window width to 45
- [x] 4.2 Configure nvim-window-picker (autoselect_one, filter out neo-tree/notify/terminal/quickfix)
- [x] 4.3 Port `open_with_smart_picker` (directory toggles; ≤1 eligible window opens directly; else window picker) and map to `w` and `<cr>`

## 5. Telescope & vim.ui.select (`lua/plugins/telescope.lua`)

- [x] 5.1 Load the `ui-select` extension with the dropdown theme
- [x] 5.2 Remap `<leader><leader>` to `find_files`, `<leader>ff` to `builtin.resume`; remove `<leader>f.`
- [x] 5.3 Verify: `dap.continue()` with multiple configurations shows a telescope picker every time

## 6. Diagnostics toggle (`lua/plugins/lsp.lua`)

- [x] 6.1 Add `<leader>ud` toggle flipping `update_in_insert` via `vim.diagnostic.config()` with a state notification

## 7. Wrap-up

- [x] 7.1 Update `nvim-pack-lock.json` after the new plugins install and confirm clean startup (`nvim --headless "+q"` and interactive smoke test)
- [x] 7.2 Update README keymap documentation if it lists the changed maps
