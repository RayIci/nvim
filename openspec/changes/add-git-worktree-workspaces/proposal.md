# Proposal

## Why

Parallel branch work should not require abandoning Neovim or mixing buffers and state from different checkouts. Add a worktree workflow that reuses the existing Neogit installation, suggests a predictable destination, and switches complete saved workspaces safely.

## What Changes

- Reuse Neogit for worktree operations, with Telescope-backed selectors under a new `<leader>gw` group; do not install another worktree plugin.
- Provide creation from an existing local branch, a remote-tracking branch, or a new branch, followed by an editable, prefilled absolute destination.
- Default to `<main-checkout>.worktrees/<local-branch-name>`, regardless of the main checkout's parent folder or which linked worktree initiated creation. Preserve branch-name slashes as subdirectories and keep remote names out of the suggested local path.
- Switch the whole workspace in the same Neovim instance: save the outgoing session and sidecar state, then restore the destination's buffers, tabs, layout, pins, breakpoints, and explorer state, or start clean if it has no saved state.
- Coordinate debounced saves and deferred restores so outgoing or stale callbacks cannot overwrite another worktree's state.
- Guard unsaved edits and live resources before switching; confirm deletion and protect the main checkout, current worktree, and dirty worktrees. Report failures explicitly without silently discarding edits or claiming a failed operation succeeded.
- Route Neogit's configured status-buffer worktree entry point through the same managed workflow. Keep unrelated Git actions, session mappings, and ordinary startup behavior unchanged.
- Keep worktree creation local: no implicit fetching, rebasing, pushing, copying ignored files, or installing project dependencies.

## Capabilities

### New Capabilities

None. Worktree management belongs to the existing Git integration, and workspace transitions extend the existing UI/session capability.

### Modified Capabilities

- `git-integration`: Neogit-backed worktree discovery, creation, stable editable destination defaults, safe removal, and discoverable managed entry points.
- `ui-shell`: Whole-workspace worktree switching, transition guards, per-checkout state isolation, and protection against stale persistence callbacks.

## Impact

- Extend `lua/plugins/neogit.lua` and add a focused worktree integration module alongside the existing plugin modules.
- Extend `lua/config/workspace.lua` and `lua/plugins/auto-session.lua` with transition-aware state handling while preserving their existing persistence locations.
- Wire setup and which-key in `lua/plugins/init.lua` and `lua/plugins/whichkey.lua`; update the README with the workflow, destination rule, limits, and keymaps.
- Reuse Neogit, Telescope, auto-session, scope.nvim, bufferline, neo-tree, and DAP already present in the configuration. No new plugin, external executable beyond Git, or plugin-manager migration is required.
- Add isolated headless regression coverage for path resolution, real Git worktree operations, guarded session transitions, and delayed callback isolation.
