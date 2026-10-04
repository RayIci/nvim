# Proposal

## Why

The user wants to try oil.nvim, which edits the filesystem as a buffer, without giving up neo-tree, whose sidebar, session persistence and git status are already set up. Oil therefore goes in as a trial explorer next to neo-tree, and removing it later should take only a small revert.

## What Changes

- Add `stevearc/oil.nvim` to the `vim.pack.add()` list in `lua/config/pack.lua` and to the lockfile.
- New `lua/plugins/oil.lua` module with `setup()`, registered in `lua/plugins/init.lua` next to neo-tree.
- `<leader>E` opens oil in a floating window on the current file's directory (or cwd when the buffer has no file).
- Oil does **not** take over directory buffers (`default_file_explorer = false`), so `nvim .` and `:e dir/` still open neo-tree.
- **BREAKING (keymap):** `<leader>E` stops being "Neotree reveal". Reveal is redundant, because neo-tree's `follow_current_file` already focuses the current file when `<leader>e` opens the tree.
- Oil's filetype is kept out of the winbar breadcrumb and out of session saves.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `ui-shell`: adds a requirement for the oil floating explorer on `<leader>E`, which coexists with neo-tree (neo-tree keeps `<leader>e` and ownership of directory buffers).

## Impact

- **Code:** `lua/config/pack.lua`, `lua/plugins/oil.lua` (new), `lua/plugins/init.lua`, `lua/plugins/neotree.lua` (drop the reveal map), `lua/plugins/barbecue.lua` (exclude `oil`), `lua/plugins/auto-session.lua` (`bypass_save_filetypes` gains `oil`).
- **Dependencies:** oil.nvim (uses the already-installed nvim-web-devicons).
- **Lockfile:** `nvim-pack-lock.json` gains an `oil.nvim` entry.
- **Rollback:** delete `oil.lua` and its init line, remove the pack entry, and restore the `<leader>E` reveal mapping.
