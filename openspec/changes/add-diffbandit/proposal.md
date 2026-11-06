# Proposal

## Why

diffbandit.nvim offers a different way to review changes. It shows two panes that each keep their real shape and line numbers, with a connector gutter between them instead of padding. It also has a commit panel, a three-pane conflict resolver and folder diffs. The goal is to try it for a while next to diffview, without changing the existing git tools, and then decide whether it should replace diffview.

## What Changes

- Install `CoreyKaylor/diffbandit.nvim` through vim.pack, tracking `main` (`version = "main"`), because the latest release, v0.3.0, lacks `close()`, `:DiffBanditClose` and commit-message drafts. Once a release includes them, switch to `vim.version.range("0")` so updates follow releases only. The lockfile records the exact revision.
- Add a `<leader>gx` which-key group with diffbandit's main views:

  | Key | Opens |
  |---|---|
  | `gxx` | all working-tree changes |
  | `gxs` | staged changes |
  | `gxf` | the current file |
  | `gxc` | the commit panel |
  | `gxb` | the branch-comparison picker |
  | `gxl` | the commit log |
  | `gxm` | its own menu |
  | `gxq` | close the view in this tab |
- Inside diffbandit's views, `-` replaces its default `<Space>` for hunk and file staging, amend toggling and folder expanding. `<Space>` is the leader key.
- Close every open diffbandit view when a worktree switch tears the workspace down, and before the exit-time session save. Saved sessions then never contain diffbandit's scratch buffers.
- Document the new keys and the trial in the README.
- Nothing changes for diffview, Neogit (including its diffview integration), gitsigns, git-conflict, lazygit, octo or agentdiff.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `git-integration`: adds a requirement for diffbandit diff review (install, version range, `<leader>gx` keys and the in-view staging key), and one for closing diffbandit views when the workspace is replaced or saved on exit.

## Impact

- **New:** `lua/plugins/diffbandit.lua`, holding the spec, setup, keymaps and the git-worktree participant.
- **Edited:**
  - `lua/plugins/init.lua`: module list.
  - `lua/plugins/whichkey.lua`: the `<leader>gx` group.
  - `lua/plugins/auto-session.lua`: an exit-only pre-save hook.
  - `README.md`.
  - `nvim-pack-lock.json`: the new entry.
- **Dependency:** diffbandit.nvim, Apache-2.0, Neovim 0.10+, no plugin dependencies. In Windows Terminal it draws connectors with Unicode cells, because the terminal has no Kitty graphics protocol.
- **Branch:** `add-diffbandit`, stacked on `refactor-config-and-extract-plugins`, because the change uses that branch's `M.spec` module pattern.
- **Not in scope:**
  - Removing or remapping diffview.
  - Installing the `bin/diffbandit` launcher or the git difftool/mergetool setup.
  - Making commitsmith work in diffbandit's commit-message window.
