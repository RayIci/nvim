# Tasks

## 1. Plugin-side integrations (cross-repo)

- [x] 1.1 On a feature branch of `~/Github/agentdiff.nvim`, add `lua/agentdiff/integrations/snacks_explorer.lua` (`format` wrapper with file and collapsed-dir marks, `setup()` refreshing open explorers on `AgentdiffChanged`) with a test in that repository's suite; verify that suite passes
- [x] 1.2 On a feature branch of `~/Github/git-worktree.nvim`, add `lua/git-worktree/integrations/snacks_explorer.lua` (`available`, `reset`) with a test; verify that repository's suite passes
- [x] 1.3 On the vale.nvim feature branch from `adopt-snacks-ui`, add the explorer groups (tree, git status, directory icon via `FolderIcon`); verify vale.nvim's suite passes
- [x] 1.4 Add the `NVIM_DEV_PLUGINS=1` runtimepath override for local checkouts of these three repositories; verify `NVIM_DEV_PLUGINS=1 nvim --headless +"lua print(package.searchpath('agentdiff.integrations.snacks_explorer', package.path) or vim.api.nvim_get_runtime_file('lua/agentdiff/integrations/snacks_explorer.lua', false)[1])" +qa` prints the local path

## 2. Explorer

- [x] 2.1 Create `lua/plugins/explorer.lua`: `<leader>e` toggle, 45-column sidebar, follow file, git and diagnostics, directory hijack, hide lists with the `H` action, never-shown globs, smart open on `<cr>`/`w`/`l`, `Y`, `n`, global Ctrl keys unmapped in the list, the agentdiff format; verify with a new `tests/explorer.lua` covering the hide list (and `H`), never-shown files, single-window open without prompt, and `<C-l>` not mapped in the list buffer
- [x] 2.2 Add the `QuitPre` last-window close and the folder-icon highlight on `ColorScheme`; verify in `tests/explorer.lua` that `:q` on the only file window exits a headless instance with the explorer open, and that `FolderIcon` is used when defined
- [x] 2.3 Point bufferline's offset, auto-session's bypass filetypes and lualine's extension list at the snacks explorer, and remove `lua/plugins/neotree.lua`; verify with `grep -ri "neo-tree\|neotree" lua` returning only the migration read in `workspace/explorer.lua`

## 3. Workspace persistence and refresh

- [x] 3.1 Rewrite `lua/config/workspace/explorer.lua` (tree method wrappers + `on_show`/`on_close` → `saver.touch`, save of open dirs, restore with `Tree:open`, managed wait on `on_show`, one-time read of `neotree/` files, `SessionLoadPost` scrub); verify with updated `tests/workspace.lua` and `tests/workspace-startup.lua` cases for save on expand/collapse/open/close, restore after a session load, the unopened-explorer memory, the migration, and no leftover explorer window after a simulated `:restart` session
- [x] 3.2 Switch git-worktree's integrations from `neotree` to `snacks_explorer` in `lua/plugins/git-worktree.lua`; verify with the `tests/workspace.lua` switch cases (explorer expansion differs per worktree and is restored on switching back)
- [x] 3.3 Remove the neo-tree call from `config/autocmds.lua` and add the explorer refresh on FocusGained/TermLeave and `User AgentdiffChanged`; verify with `NVIM_PROFILE=1` (from `add-runtime-profiling`) that a session of buffer switches and idling starts no `git` process, and manually that an outside edit in a collapsed folder shows its git mark after refocusing
- [x] 3.4 `vim.pack.del` neo-tree.nvim, nvim-window-picker and nui.nvim (nui kept: pymple.nvim requires it), after checking with `grep -rl "require(\"nui" ~/.local/share/nvim-new/site/pack/core/opt/*/lua` that no remaining plugin needs nui; verify a headless start has no errors and `tests/plugin-modules.lua` passes

## 4. Docs and merge

- [x] 4.1 Update the README: explorer section, its keys (including names that differ from neo-tree's), the hide-list `H`, and `NVIM_DEV_PLUGINS`; verify each documented key against `:map` in an explorer buffer
- [ ] 4.2 Merge the agentdiff, git-worktree and vale.nvim branches, update the lockfile with `vim.pack.update()`, and remove the dev override from the default path; verify `tests/workspace.lua` and `tests/explorer.lua` pass against the installed plugins
