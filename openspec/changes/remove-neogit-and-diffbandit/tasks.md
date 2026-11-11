# Tasks

## 1. Remove neogit

- [x] 1.1 Delete `lua/plugins/neogit.lua`, drop `"neogit"` from `lua/plugins/init.lua`, and drop `"neogit"` from git-worktree's integrations in `lua/plugins/git-worktree.lua`; verify with `nvim --headless -u NONE -l tests/plugin-modules.lua` passing
- [x] 1.2 Remove the Neogit cases and the neogit setup from `tests/workspace.lua`, rewriting the linked-checkout creation case to check the created worktree's HEAD with `git rev-parse`; verify with `nvim --headless -u NONE -l tests/workspace.lua` passing
- [x] 1.3 Update the commitsmith comment in `lua/plugins/commitsmith.lua` and the `NeogitStatus` entry in `lua/plugins/barbecue.lua`; verify with `grep -ri neogit lua tests` returning nothing

## 2. Remove diffbandit

- [x] 2.1 Delete `lua/plugins/diffbandit.lua` and `tests/diffbandit.lua`; drop the module from `lua/plugins/init.lua`, the `<leader>gx` group from `lua/plugins/whichkey.lua`, the pre-save hook from `lua/plugins/auto-session.lua` and the participant from `lua/plugins/git-worktree.lua`; verify with `grep -ri diffbandit lua tests` returning nothing and `tests/workspace.lua` passing
- [x] 2.2 Uninstall both plugins with `vim.pack.del({ "neogit", "diffbandit.nvim" })` and verify that `nvim-pack-lock.json` no longer lists them and that a headless start reports no errors (`NVIM_APPNAME=nvim-new nvim --headless +qa`)

## 3. Docs

- [x] 3.1 Remove the README's diffbandit section, the Neogit mentions in the worktree section, and the `<leader>gx` and `<leader>gn/gc/gp/gP` rows of the keymap table; verify with `grep -i "neogit\|diffbandit" README.md` returning nothing
