# Design

## Context

Plugins are installed through the single `vim.pack.add()` list in `lua/config/pack.lua`. Each plugin is set up by its own `lua/plugins/<name>.lua` module, which owns that plugin's keymaps, and modules are called in a fixed order from `lua/plugins/init.lua`. neo-tree owns `<leader>e` (toggle) and `<leader>E` (reveal), with `follow_current_file` enabled, and it hijacks directory buffers by default (`hijack_netrw_behavior = "open_default"`). Several subsystems collect buffers by `buflisted`: bufferline, `config/buffers.lua` close logic, and the `config/workspace.lua` snapshots used to reconcile sessions. auto-session skips saving the filetypes in `bypass_save_filetypes`, and barbecue hides the winbar for the filetypes in `exclude_filetypes`. See proposal.md for the motivation.

## Goals / Non-Goals

**Goals:**
- Oil is fully additive: neo-tree's behavior, sessions and directory handling are unchanged.
- Removing oil is a small, local revert.

**Non-Goals:**
- Making oil the default file explorer, or the handler for `-` / directory buffers.
- Oil git-status columns, the trash/SSH adapters, or custom oil keymaps beyond the defaults.
- Window-picker integration (the float has nothing to pick).

## Decisions

**`default_file_explorer = false`.** If both neo-tree and oil claimed directory buffers, whichever `BufEnter` handler ran first would win, and the result would depend on setup order. Turning oil's claim off keeps `nvim .` exactly as it is today. *Alternative:* switch neo-tree's hijack off and let oil handle directories. Rejected because it changes existing behavior during what is only a trial.

**`<leader>E` → `require("oil").open_float()` without a path.** With no argument, oil opens the current buffer's parent directory and falls back to cwd, which matches the spec. The float closes with oil's default `q` or `<Esc>`-style mappings and leaves the window layout alone. *Alternative:* `:Oil`, which replaces the current window. Rejected per the user's choice, because a float is less disruptive while evaluating oil.

**Drop "Neotree reveal".** `follow_current_file = { enabled = true }` already reveals the current file when `<leader>e` opens the tree, so the only thing lost is a redundant key. *Alternative:* move reveal to another key. Not done because nobody asked for it, and it's trivial to add later.

**Rely on oil's default `buf_options` (`buflisted = false`, `bufhidden = "hide"`) for bufferline, buffers and workspace.** Every consumer filters on `buflisted`, so unlisted oil buffers are invisible to them without any extra code. Two explicit exclusions are still added, because these two don't filter on `buflisted`:
- barbecue `exclude_filetypes += "oil"`, because oil buffers are `buftype = acwrite` and that passes barbecue's buftype gate;
- auto-session `bypass_save_filetypes += "oil"`, which only skips a save when oil is the *only* buffer left, so it's a minor guard and not the session fix (see below).

**Re-unlist oil buffers on `BufEnter`.** Oil applies `buf_options.buflisted = false` only when it creates a buffer. Going back to an existing oil buffer with `:edit` (the second `g\` trash toggle, or revisiting a folder) relists it, so it shows in bufferline. An `oil*://*` `BufEnter` autocmd in `plugins/oil.lua` forces `buflisted = false` on every entry, for all oil adapters. *Alternative:* a bufferline `custom_filter`. Rejected because the buffer would still be listed for `config/buffers.lua`, the workspace snapshot and `:bnext`.

**Scrub oil on `SessionLoadPost`, not before saving.** Implementation showed that an oil window can still get into a session. auto-session's `close_unsupported_windows` never closes the last window, and `:restart` calls `:mksession` itself (`vim/_core/server.lua`) with no hook beforehand. Neovim has no event that fires before a session is written. Every session load does fire `SessionLoadPost`, whether from auto-session or from `:restart`, so `plugins/oil.lua` handles it there. Oil floats are closed, a normal oil window falls back to its alternate file (then any listed buffer, then an empty one), and the `oil://` buffers are wiped. This also cleans session files that already contain an oil window. *Alternative:* an auto-session `pre_save_cmds` hook. Rejected because it misses `:restart`'s session.

**Module placement.** `require("plugins.oil").setup()` goes directly after neo-tree in the UI block of `plugins/init.lua`, so the explorers sit together and rollback stays one line.

## Risks / Trade-offs

- [Oil may still register a directory hijack autocmd, or netrw-disable side effects, with `default_file_explorer = false`] → Task 3.2 verifies `nvim .` still opens neo-tree.
- [An `oil://` window is written into a session (observed: a normal window showing oil was saved and restored)] → The `SessionLoadPost` scrub removes it on load. Session files can still *contain* oil until they're next saved, but it's never visible.
- [The muscle-memory change: `<leader>E` no longer reveals in neo-tree] → `<leader>e` already focuses the current file.

## Migration Plan

This change is purely additive apart from the removed reveal mapping. To roll back:
1. Delete `lua/plugins/oil.lua` and its line in `plugins/init.lua`.
2. Remove the pack entry and run `vim.pack.del({ "oil.nvim" })`.
3. Revert the barbecue and auto-session list entries. The `SessionLoadPost` scrub lives in `oil.lua`, so it goes with step 1.
4. Restore `<leader>E` → `Neotree reveal`.
