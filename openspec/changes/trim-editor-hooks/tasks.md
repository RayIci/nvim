# Tasks

## 1. Native folding

- [x] 1.1 Set `foldmethod`/`foldtext` in `lua/config/options.lua`, the treesitter `foldexpr` where `plugins/treesitter.lua` starts a parser, the LSP `foldexpr` on attach for folding-range servers, and the indent fallback; verify with a new `tests/folds.lua` that a Lua buffer with a parser gets the treesitter foldexpr, a plain-text buffer uses indent, and a fake server advertising folding ranges switches the buffer to the LSP foldexpr
- [x] 1.2 Move `zU` to `lua/config/folds.lua`, drop the ufo remaps, remove `lua/plugins/folding.lua` and `vim.pack.del` nvim-ufo and promise-async; verify in `tests/folds.lua` that `zM` then `zR` closes and reopens folds and that a newly opened file has `foldlevel` 99

## 2. Statusline breadcrumbs

- [x] 2.1 Attach navic on LspAttach (lazy updates), add the breadcrumb component to lualine behind the `breadcrumbs` pref, and add `<leader>ub`; verify with `tests/statusline.lua` using a fake document-symbol server that the component renders `Class › Method` for a cursor inside the method and renders nothing for a terminal buffer, and that the pref survives a restart of the test instance
- [x] 2.2 Remove `lua/plugins/barbecue.lua` and `vim.pack.del` barbecue.nvim; verify `grep -ri barbecue lua` returns nothing and no window has a non-empty `winbar` after opening a code file and a terminal

## 3. Linting

- [x] 3.1 Rework `lua/plugins/lint.lua`: FileType and BufWritePost always lint; BufEnter and InsertLeave only when changedtick moved; TextChanged path removed; verify with `tests/lint.lua` using a stub linter that counts runs: one run on open, none on an edit-free insert/leave or re-entry, one after a real edit and `<Esc>`, none while typing
- [x] 3.2 Make `<leader>ud` only flip `update_in_insert`, and drop `ruff` from the python pack's linters; verify in `tests/lint.lua` that toggling does not register text-change linting, and manually that a ruff finding shows once in a Python file

## 4. Persisted toggles and key fixes

- [x] 4.1 Add the `lightbulb`, `inlay_hints`, `codelens` prefs and the `<leader>ul` key; apply them on start and on LspAttach; replace `vim.g.codelens_enabled`; verify with `tests/toggles.lua` that each toggle writes its pref, applies to an open buffer, and is restored by a fresh instance
- [x] 4.2 Remove `]t`/`[t` from `lua/plugins/neotest.lua`; verify with `:verbose nmap ]t` showing todo-comments as the owner and `<leader>tnn` still mapped
- [x] 4.3 Update the README toggles table (`<leader>ub`, `<leader>ul`, persistence notes), the folding notes and the linting triggers; verify each listed key with `:map`
