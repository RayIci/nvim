# Proposal

## Why

Two full git UIs and two diff viewers are installed, but only lazygit and diffview are used. Neogit duplicates lazygit, and diffbandit was a trial that did not stick. Both are wired deeply: neogit into git-worktree (an integration plus the status `w` menu) and the workspace tests, and diffbandit into auto-session's pre-save hook and git-worktree's participants. That wiring is cost and code with no remaining user.

## What Changes

- **BREAKING** Remove neogit and its keymaps `<leader>gn` (status), `<leader>gc` (commit popup), `<leader>gp` (push popup) and `<leader>gP` (pull popup). They are dropped, not remapped: lazygit (`<leader>gg`, `<leader>gl`) covers these flows.
- **BREAKING** Remove diffbandit and its `<leader>gx` which-key group and keymaps (`gxx`, `gxs`, `gxf`, `gxc`, `gxb`, `gxl`, `gxm`, `gxq`). diffview keeps `<leader>gd`.
- Drop the neogit integration from git-worktree's enabled integrations and the Neogit status `w` entry point. `<leader>gww`, `<leader>gwc` and `<leader>gwd` stay.
- Drop diffbandit's git-worktree participant and its auto-session pre-save hook.
- commitsmith's buffer-local `<leader>gc` in `gitcommit` buffers stays (conversation window). Only the wording about shadowing neogit goes.
- Remove the README's diffbandit section and its Neogit references.
- Remove `tests/diffbandit.lua` and the Neogit cases in `tests/workspace.lua`.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `git-integration`: neogit's requirement is removed. The gitsigns, commit-keymap and worktree-action requirements no longer refer to neogit.
- `ui-shell`: worktree switching no longer has a Neogit-menu entry point.

## Impact

- Deleted: `lua/plugins/neogit.lua`, `lua/plugins/diffbandit.lua`, `tests/diffbandit.lua`.
- Edited: `lua/plugins/init.lua` (module list), `lua/plugins/whichkey.lua` (`<leader>gx` group), `lua/plugins/auto-session.lua` (pre-save), `lua/plugins/git-worktree.lua` (integrations, participant), `lua/plugins/commitsmith.lua` (comment), `lua/plugins/barbecue.lua` (exclude list), `tests/workspace.lua`, `README.md`.
- Lockfile: `neogit` and `diffbandit.nvim` entries removed by `vim.pack.del()`.
- No change in the git-worktree.nvim repository: its neogit integration is optional and simply stays disabled.
