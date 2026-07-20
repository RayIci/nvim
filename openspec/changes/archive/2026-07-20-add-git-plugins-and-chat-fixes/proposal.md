## Why

The current config covers in-buffer git (gitsigns) and a lazygit float, but day-to-day git work still forces drops to the terminal for diffs, merge conflicts, GitHub PR review, and richer staging/commit flows. The old config (`~/dotfiles/.config/nvim`) already solved this with a proven four-plugin suite worth porting. Separately, the CopilotChat window closes on `<C-c>` from insert mode — a default the old config had already fixed — which makes the chat easy to dismiss by accident.

## What Changes

- Add **diffview.nvim**: side-by-side diffs and file history under a `<leader>gd` which-key group (open, close, refresh, toggle file panel, file/project history).
- Add **neogit**: Magit-style git UI in a floating window with diffview and telescope integrations; `<leader>gn` status, `<leader>gc` commit, `<leader>gp` push, `<leader>gP` pull.
- Add **octo.nvim** for GitHub PR/issue workflows, **pinned to commit `7566ab21843bf0de721f72891733c0372738d3ee`** (newer versions are bugged — keep a comment noting the pin and the reason), telescope picker, `enable_builtin`.
- Add **git-conflict.nvim**: merge-conflict resolution mappings under `<leader>gC` (ours/theirs/both/none/next/prev).
- Remap two gitsigns keys to make room for the old-config scheme: diffthis `<leader>gd` → `<leader>gD`, preview_hunk `<leader>gp` → `<leader>gv` (`<leader>gh` is the GitHub/Octo group prefix, as in the old config).
- Port the old config's **Octo/GitHub keymap tree** under `<leader>gh`: issues (`ghi*`), pull requests (`ghp*`), reviews (`ghr*`), comments (`ghc*`), reactions (`ghR*`), assignees/labels (`gha*`/`ghl*`), reviewers (`ghv*`), plus notifications/search/discussions. Snacks-dependent maps from the old config are not ported (no Snacks here).
- Port the old config's git-conflict quickfix maps: `<leader>gCQ` (conflicts → quickfix) and `<leader>gCq` (conflicts → Trouble).
- Fix CopilotChat window mappings: `<C-c>` no longer closes the chat from insert mode (`close.insert = ""`), `q` closes from normal mode, and diffs render as full diffs (`show_diffs.full_diff = true`). Current `<leader>a*` keymaps and the commit-message flow stay as-is.
- Add **scope.nvim** (from the old config): buffers are scoped per tabpage, so bufferline only shows the current tab's buffers; scope state is saved/restored with sessions via `ScopeSaveState`/`ScopeLoadState` auto-session hooks.
- Port the old config's **tab-management keymaps** under a `<leader>j` which-key group: next/prev/first/last, create, open-current-buffer-in-new-tab, close (also `<leader>xj`), close-others, move, and direct `<leader>j1`–`j9` jumps.

## Capabilities

### New Capabilities

None — all changes extend existing capabilities.

### Modified Capabilities

- `git-integration`: new requirements for diff/history UI (diffview), full git UI (neogit), GitHub PR/issue workflows (octo, version-pinned), and merge-conflict resolution (git-conflict); the gitsigns requirement is unchanged at spec level (the two remapped keys were never pinned in the spec).
- `editing-experience`: new requirement for CopilotChat window behavior — the chat must not close on `<C-c>` from insert mode, must close on `q` in normal mode, and must show full diffs.
- `plugin-management`: the vim.pack plugin list gains four plugins, one of which (octo.nvim) must stay pinned to a specific commit; the requirement covering plugin installation gains the notion of a commit-pinned plugin.
- `ui-shell`: new requirement for per-tabpage buffer scoping via scope.nvim, including session persistence of scope state.
- `core-keymaps`: new requirement for tab-management keymaps under `<leader>j`.

## Impact

- `lua/config/pack.lua`: four new `vim.pack.add` entries; octo pinned to a commit (mechanism to be settled in design — vim.pack `version` vs. a `PackChanged` checkout hook).
- `lua/plugins/`: four new modules (`diffview.lua`, `neogit.lua`, `octo.lua`, `git-conflict.lua`), each owning its plugin's keymaps per the existing architecture.
- `lua/plugins/init.lua`: four new `require(...).setup()` calls in the Git section.
- `lua/plugins/gitsigns.lua`: two keymap changes (`<leader>gD` diffthis, `<leader>gh` preview hunk).
- `lua/plugins/copilot-chat.lua`: add `mappings.close` and `mappings.show_diffs` opts.
- `lua/plugins/whichkey.lua`: possible new group labels (`<leader>gd` DiffView, `<leader>gC` Conflict, `<leader>j` Tabs).
- `lua/plugins/scope.lua` (new) + `lua/plugins/auto-session.lua`: scope setup and session save/restore hooks.
- `lua/config/keymaps.lua`: tab-management keymaps.
- New dependency: `gh` CLI (octo requires it at runtime; already used by the user).
- `nvim-pack-lock.json` gains the new plugins.
