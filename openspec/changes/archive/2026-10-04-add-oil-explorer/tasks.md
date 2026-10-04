# Tasks

## 1. Install

- [x] 1.1 Add `gh("stevearc/oil.nvim")` to the UI section of `vim.pack.add()` in `lua/config/pack.lua`; verify that after restart `:lua =vim.pack.get({"oil.nvim"})` lists it as installed and `nvim-pack-lock.json` gains an `oil.nvim` entry

## 2. Configure

- [x] 2.1 Create `lua/plugins/oil.lua` (module doc comment, `---@class PluginOil`, `M.setup()`) calling `require("oil").setup({ default_file_explorer = false })` and mapping `<leader>E` → `require("oil").open_float()` with desc "Oil (float)"; verify that `:map <leader>E` shows the oil mapping and its description
- [x] 2.2 Register `require("plugins.oil").setup()` right after `plugins.neotree` in `lua/plugins/init.lua`; verify that startup shows no errors (oil ships no healthcheck, so `:checkhealth oil` is not applicable; verified by `require("oil")` and the float working)
- [x] 2.3 Remove the `<leader>E` "Neotree reveal" mapping from `lua/plugins/neotree.lua`; verify that `:verbose map <leader>E` points to `plugins/oil.lua`
- [x] 2.4 Add `"oil"` to barbecue's `exclude_filetypes` and to auto-session's `bypass_save_filetypes`; verify that the oil float shows no winbar breadcrumb
- [x] 2.5 Map `<BS>` → `actions.parent` (normal mode) in oil's `keymaps`, merged with the defaults; verify that `<BS>` in the float on `lua/plugins/` moves to `lua/`, `-` still works, and insert-mode `<BS>` is unchanged
- [x] 2.6 Add a `SessionLoadPost` scrub in `lua/plugins/oil.lua` that closes oil floats, points normal oil windows at their alternate (or another listed, or an empty) buffer, and wipes `oil://` buffers; verify that sourcing a session file containing `file oil:///…` ends with no `oil://` buffer and the window on its alternate file
- [x] 2.7 Add oil keymaps `g|` → vertical split, `g-` → horizontal split, `gR` → refresh, and set `<C-s>`/`<C-h>`/`<C-l>` to `false`; verify that `g|`/`g-` from the float give a row/col layout with the file focused, and `maparg` shows the global save and TmuxNavigate maps for the three Ctrl keys in an oil buffer
- [x] 2.8 Re-unlist oil buffers on every `BufEnter` of `oil*://*` (oil only unlists on creation, and `:edit` back to an existing buffer relists it); verify that toggling `g\` twice, then `<BS>` and `<CR>`, keeps every `oil://`/`oil-trash://` buffer unlisted and out of bufferline, in the float and in a normal window

## 3. Verification

- [x] 3.1 Open `lua/plugins/oil.lua` and press `<leader>E`: a float lists `lua/plugins/`; on an empty start buffer it lists the cwd
- [x] 3.2 Run `nvim .` in the repo: it opens as before (neo-tree), with no `oil://` buffer in `:ls!`; `<leader>e` still toggles neo-tree focused on the current file
- [x] 3.3 In a scratch directory, rename a file in the oil float and `:w`, confirm the prompt: the file is renamed on disk
- [x] 3.4 Open and close the oil float, check that the bufferline has no oil entry, then `:restart`: the restored session has no `oil://` buffer in `:ls`
- [x] 3.5 Run `openspec validate add-oil-explorer --strict` and confirm it passes
