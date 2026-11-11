# Tasks

## 1. Pickers and selection prompts

- [x] 1.1 Enable `picker` (with `ui_select`), `input`, `words` and `indent` in `lua/plugins/snacks.lua` and move the `<leader>f*` and `<leader><leader>` keys there with the glob ignore lists; verify in a headless test (`tests/snacks-ui.lua`) that every listed key exists with its description and that a find-files run in a fixture tree with `node_modules/` and `.hidden` returns `.hidden` but nothing under `node_modules/`
- [x] 1.2 Switch `lua/plugins/lsp.lua` to snacks pickers (`gd`, `gD`, `grt`, `grr`, `gri`, `gO`, `<leader>lf` multi-source, `<leader>ldb`, `<leader>ldw`, `<leader>lhi`, `<leader>lho`) and native code actions (`gra`, `<leader>la`); verify with `tests/snacks-ui.lua` using a fake LSP server that a single-definition `gd` jumps without a picker and `<leader>lf` lists both references and implementations
- [x] 1.3 Point octo, auto-session and venv-selector at the snacks picker and todo-comments' `<leader>ft` at `Snacks.picker.todo_comments`; verify manually with `<leader>ghpl`, `<leader>ql`, `<leader>-pp` and `<leader>ft`, each opening a snacks picker
- [x] 1.4 Remove `lua/plugins/telescope.lua`, `lua/plugins/lspsaga.lua` and their modules from `lua/plugins/init.lua`, then `vim.pack.del` telescope.nvim, telescope-fzf-native.nvim, telescope-ui-select.nvim and lspsaga.nvim; verify with `grep -ri "telescope\|lspsaga" lua` returning nothing and `tests/plugin-modules.lua` passing

## 2. Messages and notifications

- [x] 2.1 Enable `vim._core.ui2` in `lua/config/options.lua` behind `pcall` and the `ui2` pref; verify manually that `:messages` after several notifications opens a pager closed with `q`, and that `:restart` does not wait for a key
- [x] 2.2 Map `<leader>fn` to the notification-history picker and `<leader>un` to dismiss; remove `lua/plugins/noice.lua` and `vim.pack.del` noice.nvim; verify with `tests/snacks-ui.lua` that both keys exist and `grep -ri noice lua` finds only comments that are then removed

## 3. Reference highlighting and indent guides

- [x] 3.1 Map `]]`/`[[` to `Snacks.words.jump`, remove `lua/plugins/illuminate.lua` and `vim.pack.del` vim-illuminate; verify with `tests/snacks-ui.lua` and a fake server returning two document highlights that `]]` moves to the second
- [x] 3.2 Configure `snacks.indent` with `│`, scope highlighting and the panel filter, remove `lua/plugins/indent.lua` and `vim.pack.del` indent-blankline.nvim; verify manually that guides show in a Lua file and not in help, Trouble or mason windows

## 4. Theme coverage and docs

- [x] 4.1 On a feature branch of `~/Github/vale.nvim`, add the snacks picker, input, preview, words and indent-scope groups to `lua/vale/integrations/snacks.lua` and extend its integration test; verify that vale.nvim's own test suite passes and that, with the branch loaded, `:hi SnacksPickerListCursorLine` under vale-night is not linked to a default group
- [x] 4.2 Update the README (plugins list, picker key notes, the `ui2` pref) and the blink.cmp comment about prompt buffers; verify every key in the README's `<leader>f` and `<leader>l` rows exists via `:map`
