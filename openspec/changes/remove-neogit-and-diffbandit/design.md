# Design

## Context

neogit is set up in `lua/plugins/neogit.lua`, enabled as a git-worktree integration (`lua/plugins/git-worktree.lua`) and exercised by three cases in `tests/workspace.lua`. diffbandit is configured lazily in `lua/plugins/diffbandit.lua`. Its `close_on_exit` is an auto-session `pre_save_cmds` entry, and its `participant` is registered last with git-worktree so views close before the unsaved-buffer prompt.

## Goals / Non-Goals

**Goals:**
- Remove both plugins with no dangling references (module list, which-key groups, hooks, tests, README, lockfile).
- Keep every remaining git, worktree and session behaviour unchanged.

**Non-Goals:**
- Changing git-worktree.nvim itself. Its neogit integration is opt-in by name and stays available to other users.
- Remapping the dropped keys (decided: dropped).

## Decisions

- **Uninstall with `vim.pack.del({ "neogit", "diffbandit.nvim" })`** after removing the specs, so the lockfile and the plugin directories go too. Leaving them on disk would keep them on the runtimepath until the next clean install.
- **auto-session `pre_save_cmds` keeps only `workspace.session.pre_save`.** The exit-time close existed only for diffbandit's commit buffers.
- **git-worktree integrations become `{ "auto_session", "dap", "scope", "bufferline", "neotree" }`.** `neotree` is replaced later by `move-explorer-to-snacks`.
- **Workspace tests:** drop the `NVIM_WORKSPACE_TEST_NEOGIT` override, the `require("plugins.neogit").setup()` call and the three Neogit cases. The creation-from-linked-checkout case is rewritten to assert the same rule (creation uses the linked checkout's HEAD) without Neogit's repository cache.

## Risks / Trade-offs

- [A test relied on Neogit to reproduce a stale-repository bug] → The rewritten case checks the HEAD the new worktree was created from directly with `git rev-parse`, which is the behaviour the requirement protects.
- [The vale theme still defines Neogit and diffbandit highlight groups] → Harmless for an uninstalled plugin. vale.nvim is a separate repository and is left as is.
