# Proposal

## Why

AI agents (Claude Code, Copilot CLI, Codex) run in a tmux pane next to Neovim and write straight to disk, so their edits arrive as silent buffer reloads with no way to see, step through, or accept/reject what changed. VS Code's agent mode solves this with an inline review diff (removed/added lines, Keep/Undo per change, file or session) that shows only the agent's edits, never the user's; this change brings that experience to Neovim without moving the agent out of tmux and without any per-harness configuration.

## What Changes

- Add **agentdiff**, a self-contained Neovim plugin living in `lua/agentdiff/` (relocatable to its own repository without code changes, no plugin dependencies, Neovim + git only), following the commitsmith precedent.
- **Attribution by writer**: any change on disk that Neovim did not make is an agent change and becomes a pending review; anything Neovim does — typing, `:w`, format-on-save, LSP edits, and claimed tool operations — is the user's and never becomes a diff. No harness hooks are required, so it works identically for every agent.
- **Baseline store**: a per-project shadow git directory under Neovim's state path (never touching the project's own `.git`), shared by every Neovim instance on that project, persisted so pending reviews survive restarts, honouring `.gitignore`.
- **User edits are rebased onto the baseline** with a three-way merge, so the user's typing outside an agent change never shows as a diff, edits inside an agent change become part of it, and an agent write to a buffer with unsaved user edits is merged into the buffer instead of conflicting.
- **Git-guard**: when HEAD or the index moves (checkout, pull, stash, commit), files git itself rewrote are folded into the baseline instead of being flagged; pending agent changes survive commits.
- **Review UI**: VS Code-style inline overlay (removed lines as virtual lines, added lines highlighted, a hint with the position "N/M" and keys), navigation between changes across files, Keep/Undo per change, per file and for all files, partial Keep/Undo of a visual line range (beyond VS Code), a changed-files panel with per-file counts, and an inline ↔ side-by-side toggle. Undo is itself undoable.
- **Public API**: actions for every operation, `claim(paths)` for tools that write files directly, and a statusline component; the plugin registers no keymaps unless asked to.
- **Host wiring** in `lua/plugins/agentdiff.lua`: options, `]a`/`[a`, `]A`/`[A` and a `<leader>r` "review" which-key group, claims for oil and grug-far, the statusline widget, and a vale colour integration.
- **Headless test suite** for the plugin (`nvim --headless -l`), with no test-framework dependency.

## Capabilities

### New Capabilities
- `agent-change-review`: detecting, attributing, displaying and resolving file changes made by external agents — baseline store, writer attribution and claims, merging with user edits, git-guard, inline overlay, navigation, keep/undo at every granularity, changed-files panel, statusline component and the plugin's public API. *Moved:* once the plugin got its own repository, this capability's spec moved to `openspec/specs/agent-change-review/` in RayIci/agentdiff.nvim, where its changes are now planned; this change keeps only the configuration's deltas.

### Modified Capabilities
- `editing-experience`: adds the host wiring for the agentdiff plugin (keymaps, which-key group, tool claims, statusline widget).
- `vale-engine`: the "Required plugin integrations" list gains agentdiff.

## Impact

- New code: `lua/agentdiff/` (plugin), `lua/plugins/agentdiff.lua` (host wiring), `lua/vale/integrations/agentdiff.lua`, a test runner and test files for the plugin.
- Touched: `lua/plugins/init.lua` (setup order), `lua/plugins/whichkey.lua` (group), vale integrations index.
- Runtime: git must be on `PATH`; a shadow git dir per project under `stdpath("state")/agentdiff/`. The first snapshot of a large project runs in the background.
- Interplay: coexists with gitsigns (git gutter vs HEAD) and with the existing external-change `checktime` autocmd in `lua/config/autocmds.lua`; claude/copilot/codex need no configuration.
- No new plugin dependencies.
