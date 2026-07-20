## 1. Plugin installation (pack.lua)

- [x] 1.1 Add `sindrets/diffview.nvim`, `NeogitOrg/neogit`, and `akinsho/git-conflict.nvim` to the "Git & AI" section of `lua/config/pack.lua`
- [x] 1.2 Add `pwntester/octo.nvim` pinned via `version = "7566ab21843bf0de721f72891733c0372738d3ee"` with a comment noting newer versions are bugged (pin carried over from the old dotfiles config)
- [x] 1.3 Start Neovim once to let vim.pack clone the new plugins; confirm octo is checked out at the pinned commit and `nvim-pack-lock.json` is updated

## 2. Gitsigns keymap relocation

- [x] 2.1 In `lua/plugins/gitsigns.lua`, remap diffthis from `<leader>gd` to `<leader>gD` and preview_hunk from `<leader>gp` to `<leader>gh`

## 3. New plugin modules

- [x] 3.1 Create `lua/plugins/diffview.lua`: `setup()` with default config, `<leader>gd` which-key group ("DiffView") and keymaps `gdd`/`gdo` open, `gdc` close, `gdr` refresh, `gdt` toggle file panel, `gdf` file history (current file), `gdp` file history (project)
- [x] 3.2 Create `lua/plugins/neogit.lua`: floating window, diffview + telescope integrations, old-config sign glyphs; keymaps `<leader>gn` status, `<leader>gc` commit popup, `<leader>gp` push popup, `<leader>gP` pull popup
- [x] 3.3 Create `lua/plugins/octo.lua`: telescope picker, `enable_builtin = true`; include a comment referencing the version pin in pack.lua
- [x] 3.4 Create `lua/plugins/git-conflict.lua`: `default_mappings` set to `<leader>gCo` ours, `<leader>gCt` theirs, `<leader>gC0` none, `<leader>gCb` both, `<leader>gCn` next, `<leader>gCp` prev; register `<leader>gC` which-key group ("Conflict")
- [x] 3.5 Wire the four modules into the Git section of `lua/plugins/init.lua` (after gitsigns/lazygit, diffview before neogit)

## 4. CopilotChat window fix

- [x] 4.1 In `lua/plugins/copilot-chat.lua`, add `mappings = { close = { normal = "q", insert = "" }, show_diffs = { full_diff = true } }` to the setup opts

## 5. Verification

- [x] 5.1 Headless smoke test: `nvim --headless "+lua print('ok')" +qa` reports no startup errors
- [x] 5.2 Interactive checks: `<leader>gdd` opens/`<leader>gdc` closes diffview; `<leader>gn` opens neogit floating status; `:Octo pr list` works (or errors only about repo/auth, not plugin load); which-key shows DiffView and Conflict groups; `<leader>gD`/`<leader>gh` trigger the relocated gitsigns actions
- [x] 5.3 In CopilotChat, verify `<C-c>` in insert mode no longer closes the window and `q` in normal mode does

## 6. Scope (per-tab buffers)

- [x] 6.1 Add `tiagovla/scope.nvim` to `lua/config/pack.lua` and install it
- [x] 6.2 Create `lua/plugins/scope.lua` (plain `setup()`) and wire it into the UI section of `lua/plugins/init.lua`
- [x] 6.3 Add auto-session hooks: `ScopeSaveState` in `pre_save_cmds`, `ScopeLoadState` in `pre_restore_cmds`

## 7. Tab-management keymaps

- [x] 7.1 Add the `<leader>j` tab keymaps to `lua/config/keymaps.lua` (next/prev/first/last, create, current-buffer-to-new-tab, close + `<leader>xj`, close others, move, `j1`–`j9`; no `gt`/`gT` remaps) and register the `<leader>j` group in `whichkey.lua`

## 8. Verification (scope + tabs)

- [x] 8.1 Headless checks: clean startup, `ScopeSaveState`/`ScopeLoadState` commands exist, all `<leader>j*` keymaps registered, `<leader>js` opens the current buffer in a new tab

## 9. Octo GitHub keymaps

- [x] 9.1 Move gitsigns preview_hunk from `<leader>gh` to `<leader>gv` (frees the `<leader>gh` prefix for the GitHub tree)
- [x] 9.2 Add the old-config Octo keymap tree to `lua/plugins/octo.lua` (issues `ghi*`, PRs `ghp*`, reviews `ghr*`, comments `ghc*`, reactions `ghR*`, assignees/labels `gha*`/`ghl*`, reviewers `ghv*`, notifications/search/discussions `ghn/ghs/ghd`; skip Snacks-based maps)
- [x] 9.3 Add `<leader>gCQ` (quickfix) and `<leader>gCq` (Trouble) conflict-list maps to `lua/plugins/git-conflict.lua`
- [x] 9.4 Register the new which-key groups (`gh`, `ghi`, `ghp`, `ghr`, `ghc`, `ghR`, `gha`, `ghl`, `ghv`) in `whichkey.lua`
- [x] 9.5 Headless checks: clean startup, all new maps registered, gitsigns preview at `<leader>gv`
