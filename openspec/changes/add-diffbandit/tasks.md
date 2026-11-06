# Tasks

## 1. Install diffbandit

- [x] 1.1 Create `lua/plugins/diffbandit.lua` with `M.spec = { { src = "CoreyKaylor/diffbandit.nvim", version = vim.version.range("0") } }` and a `setup()` that calls `require("diffbandit").setup()`. Add `"diffbandit"` to `M.modules` in `lua/plugins/init.lua` after `"diffview"`. Verify with `nvim --headless -u NONE -l tests/plugin-modules.lua`.
- [x] 1.2 Start Neovim once so vim.pack installs it. Verify that `nvim-pack-lock.json` gains a `diffbandit.nvim` entry whose revision is the `v0.3.0` tag's commit (`git ls-remote https://github.com/CoreyKaylor/diffbandit.nvim v0.3.0`), and that a clean headless start exits 0 with no errors.

## 2. Options and keymaps

- [ ] 2.1 Pass the staging-key options to `setup()`. All four are `-`:
  - `actions.keys.toggle_stage`
  - `git.panel.keys.toggle_stage`
  - `git.panel.keys.toggle_amend`
  - `folder.keys.toggle_expand`

  Verify in a headless check against a temporary git repository with one modified file. After `:DiffBanditGit`, the right pane has a buffer-local `-` mapping described "DiffBandit: …", and no buffer-local `<Space>` mapping in the diff panes or the commit panel.
- [ ] 2.2 Add the `<leader>gx` keymaps:

  | Key | Runs |
  |---|---|
  | `gxx` | `DiffBanditGit` |
  | `gxs` | `DiffBanditGit --staged` |
  | `gxf` | `DiffBanditGitCurrent` |
  | `gxc` | `DiffBanditCommitPanel` |
  | `gxb` | `require("diffbandit").git_compare_branches({})` |
  | `gxl` | `DiffBanditGitLog` |
  | `gxm` | `DiffBanditGitMenu` |
  | `gxq` | `DiffBanditClose` |

  Give each a `desc`. Add `{ "<leader>gx", group = "diffbandit" }` to `lua/plugins/whichkey.lua`. Verify with `maparg` in a headless start that all eight exist with descriptions and that `<leader>gdd` still maps to `DiffviewOpen`.
- [ ] 2.3 In the headless repository check, verify the keys behave:
  - `-` stages the hunk under the cursor (`git diff --cached` is no longer empty), and `-` again unstages it.
  - `<leader>gxq` closes the view and its tab.
  - `u` after an ordinary edit in the right pane undoes that edit.

## 3. Close views with the workspace

- [ ] 3.1 Add `M.close_all()` to `lua/plugins/diffbandit.lua`. It returns at once when `package.loaded.diffbandit` is nil. Otherwise, for every tab where `require("diffbandit").is_running({ tab = t, panel = true })`, it makes the tab current and calls `close()`, then returns to the starting tab if it still exists. Verify headlessly:
  - With a diff view in one tab and a standalone commit panel in another, both close and the remaining tabs are untouched.
  - In a fresh start where diffbandit was never opened, `close_all()` leaves `package.loaded.diffbandit` nil.
- [ ] 3.2 Add `M.participant = { name = "diffbandit", check = M.close_all }`. In `lua/plugins/git-worktree.lua`, register it right after the workspace participant. Verify in a headless switch between two worktrees of a temporary repository, using the installed git-worktree.nvim and auto-session the way `tests/workspace.lua` does:
  - With a view open, the switch completes, and the outgoing session file has no `diffbandit` buffer names.
  - With a typed but uncommitted commit-panel message and another modified buffer, "Save all and switch" creates no commit (`git rev-parse HEAD` unchanged), and reopening the commit panel in that repository restores the message.
  - A cancelled switch leaves the workspace where it was and the view closed.
- [ ] 3.3 Add `M.close_on_exit()`, which calls `close_all()` only when `vim.v.exiting ~= vim.NIL`. Append it to `pre_save_cmds` in `lua/plugins/auto-session.lua`, after `workspace.session.pre_save`. Verify headlessly:
  - With a view open, `:AutoSession save` leaves the view open.
  - Quitting with a view open writes a session file with no `diffbandit` buffer names.
  - Restoring that session gives the normal tabs only.
- [ ] 3.4 Turn the checks from 2.1 to 3.3 into `tests/diffbandit.lua`. It runs as `nvim --headless -u NONE -l tests/diffbandit.lua` against the installed plugins, in temporary XDG directories, following `tests/workspace.lua`. Verify it passes, and that `tests/workspace.lua`, `tests/workspace-startup.lua`, `tests/state.lua` and `tests/plugin-modules.lua` still pass.

## 4. Documentation

- [ ] 4.1 Update the README:
  - The `<leader>gx` keys and the in-view `-` staging key go in the key-binding section.
  - Add a short "diffbandit (trial)" note covering four things: it sits next to diffview, updates follow releases only, views close on worktree switch and on exit, and commitsmith may not attach to its commit-message window.
  - Add `tests/diffbandit.lua` wherever the tests are listed.

  Verify that every documented key exists (`maparg`) and that the test command runs as written.

## 5. Integration checks

- [ ] 5.1 Run `stylua --check` (`~/.local/share/nvim/mason/bin/stylua`) on the changed Lua files and `openspec validate add-diffbandit --strict`. Do a fresh-machine start with empty temporary `XDG_DATA_HOME`/`XDG_STATE_HOME` and verify diffbandit is cloned at the locked revision with no startup errors. Verify all pass.

## Workflow follow-up

- Make small commits on `add-diffbandit`, stacked on `refactor-config-and-extract-plugins`.
- The user tries diffbandit for a while, then decides between keeping both, replacing diffview (a separate change), or removing diffbandit.
- Archive `add-diffbandit` after `refactor-config-and-extract-plugins` is archived, since both modify `git-integration`.
