# Design

## Context

Today neo-tree is configured in `lua/plugins/neotree.lua` (window picker, `Y`, `n`, hide lists, agentdiff component, libuv watcher). Its state is persisted by `lua/config/workspace/explorer.lua`, which subscribes to neo-tree's `AFTER_RENDER`/window events, reads and writes `stdpath("state")/neotree/<cwd-key>.json`, wipes foreign neo-tree buffers left by `:restart`, and reopens the tree after session load (synchronously for managed worktree switches, waiting for a render). `config/autocmds.lua` fires neo-tree's `GIT_EVENT` from BufEnter, CursorHold, FocusGained and TermLeave. git-worktree resets neo-tree via its `neotree` integration, and agentdiff marks nodes via `agentdiff.integrations.neotree`.

The snacks explorer is a picker source (`Snacks.explorer()`, list filetype `snacks_picker_list`) with a module-level tree (`snacks.explorer.tree`), where each directory node has an `open` flag and `Tree:open(path)`/`Tree:close(path)`/`Tree:toggle(path)`. It watches open directories and `.git` with libuv (`snacks.explorer.watch`) and exposes `on_show`/`on_close` picker hooks and per-source `format` functions.

## Goals / Non-Goals

**Goals:**
- Behaviour in the specs, with persistence that writes only when state changes.
- Integrations owned by the plugins they belong to (agentdiff, git-worktree), not reimplemented in the configuration.

**Non-Goals:**
- Changing oil, bufferline pins, scope, or auto-session behaviour.
- A right-side or floating explorer layout.

## Decisions

- **`lua/plugins/explorer.lua` owns the explorer.** It configures `picker.sources.explorer`:
  - layout: `sidebar` preset, 45 columns;
  - `hidden = true` and `ignored = true`: dotfiles and git-ignored files visible, matching neo-tree's `hide_dotfiles = false` / `hide_gitignored = false`;
  - `exclude` holds the never-shown globs (`__pycache__`, `.conform.*`);
  - a separate `hide_list` of globs is applied through `exclude` too, and `H` is remapped to a custom action that drops or re-adds it and refreshes. This gives neo-tree's "hidden by name, revealable" semantics, which snacks' own `H` (dotfiles) does not.
- **Smart open** is a custom action bound to `<cr>`, `w` and `l`:
  - directories run `confirm`, which toggles them;
  - files count the eligible windows (not the explorer, `nofile`, terminal or quickfix) and run `confirm` when there are at most one, otherwise `pick_win` then `jump`;
  - snacks' `pick_win` labels windows just as nvim-window-picker did, which is why that plugin can go.
- **`Y`** reuses the existing `copy_node_path` chooser, rewritten against snacks items (`item.file`). **`n`** calls `require("easy-dotnet").create_item(dir)` with the item's directory.
- **Global keys:** the explorer list window's `keys` set `<c-j>`, `<c-k>`, `<c-s>` and `<c-t>` to `false`, so the global mappings apply. `<c-h>`/`<c-l>` are not mapped by snacks.
- **Last-window quit:** a `QuitPre` autocmd closes the explorer picker when every other window in the tab is a float or the explorer. This replaces neo-tree's `close_if_last_window`.
- **Persistence rewritten in `config/workspace/explorer.lua`, same shape `{ nodes, is_open }`:**
  - *Changes are detected* by wrapping `Tree:open`, `Tree:close`, `Tree:toggle` and `Tree:close_all` (the pattern `workspace/breakpoints.watch` already uses for dap) plus the picker's `on_show`/`on_close`. Each calls the existing debounced `saver.touch`. Renders no longer cause writes.
  - *Saving* collects every directory node with `open = true` under cwd.
  - *Restoring* calls `Tree:open(dir)` for each saved dir, then opens the explorer when `is_open`. A managed restore waits for the picker's first `on_show` (bounded `vim.wait`), preserving the synchronous guarantee the worktree switch relies on.
  - *Migration:* if `explorer/<key>.json` is missing and `neotree/<key>.json` exists, read the latter. The next save writes the new path.
- **`:restart` leftovers:** a `SessionLoadPost` scrub (like oil's) closes or replaces windows showing a `snacks_picker_*` or `snacks_layout_box` buffer, then lets the restore reopen the real explorer. It replaces `wipe_foreign_buffers`.
- **External-change refresh:** `config/autocmds.lua` keeps the `checktime` part unchanged and drops the neo-tree call. A FocusGained/TermLeave handler and a `User AgentdiffChanged` handler call the explorer's update when an explorer picker is open. Snacks' own watcher already covers `.git` index changes and open folders.
- **agentdiff integration** (`agentdiff.integrations.snacks_explorer`, in that repository):
  - `format(item, picker)` wraps `Snacks.picker.format.file` and appends the mark for `path_status(item.file)`: a file mark, or a dir mark only when `not item.open`;
  - `setup()` refreshes open explorer pickers on `AgentdiffChanged`;
  - the configuration passes `format` into the explorer source.
- **git-worktree integration** (`git-worktree.integrations.snacks_explorer`): `available()` checks for `snacks.picker`; `reset()` closes every explorer picker and clears the tree's open nodes, so the destination starts clean before workspace restore.
- **Folder icons:** set `SnacksPickerDirectory` (and the icon group snacks uses for directories) to `FolderIcon` or `#E5C07B` on `ColorScheme`, as `neotree.lua` does today.
- **Bufferline offset** targets `snacks_layout_box` with the text "Files".

## Risks / Trade-offs

- [Wrapping `snacks.explorer.tree` methods depends on snacks internals] → Wrapping is guarded (skip if a method is missing). `tests/workspace.lua` covers save on expand, collapse, open and close, so a snacks update that renames them fails a test instead of silently losing state. The lockfile pins snacks.
- [Hide-list toggle via `exclude` re-runs the finder] → It is a deliberate keypress, not a hot path.
- [Explorer refresh on `AgentdiffChanged` during heavy agent activity] → agentdiff already debounces that event. The refresh is skipped when no explorer is open.
- [Managed restore waits on `on_show`] → Bounded at 10 s with the same error path as today ("Explorer restoration did not complete").

## Migration Plan

1. Land the agentdiff and git-worktree integrations on feature branches, and load the local checkouts in the configuration while the branches are open (`vim.opt.rtp:prepend` behind `NVIM_DEV_PLUGINS=1`).
2. Switch the configuration, run `tests/workspace.lua` and `tests/workspace-startup.lua`, then merge the plugin branches and drop the dev override.
3. Rollback: revert the configuration commit. The old `neotree/` state files are only read, never deleted.
