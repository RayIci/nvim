## Context

The config uses native `vim.pack` (`lua/config/pack.lua`) with one explicit setup module per plugin in `lua/plugins/`, wired in order by `lua/plugins/init.lua`. Git tooling today is gitsigns + a hand-rolled lazygit float. The old config (`~/dotfiles/.config/nvim/lua/plugins/git/`) carries working specs for diffview, neogit, octo, and git-conflict written for a lazy.nvim-style installer (`mnvim.plugins:install`), which must be translated to this architecture. CopilotChat is configured in `lua/plugins/copilot-chat.lua` with default window mappings.

## Goals / Non-Goals

**Goals:**
- Port the four git plugins with the old config's behavior and keymaps, adapted to `vim.pack` + setup-module architecture.
- Keep octo.nvim on the known-good commit `7566ab21843bf0de721f72891733c0372738d3ee`, documented with a comment.
- Resolve `<leader>g` keymap collisions in favor of the old scheme.
- Stop `<C-c>` from closing the CopilotChat window in insert mode; `q` closes in normal mode; full diffs in chat.

**Non-Goals:**
- No changes to the CopilotChat `<leader>a*` keymaps, model selection, or the commit-message generation flow.
- No lazy-loading framework — plugins follow the existing eager `setup()` pattern (octo's old `cmd = "Octo"` lazy trigger is dropped; `require("octo").setup()` at startup is acceptable in this architecture).
- No porting of the old config's gitsigns or lazygit variants — current ones stay.

## Decisions

**D1 — Octo pin via `vim.pack` `version` field.** `:h vim.pack.Spec` documents `version` as accepting a branch, tag, **or commit hash**. So the pin is simply `{ src = gh("pwntester/octo.nvim"), version = "7566ab21843bf0de721f72891733c0372738d3ee" }` with a comment explaining newer versions are bugged. Alternative considered: a `PackChanged` checkout hook (like the fzf-native build hook) — unnecessary given first-class support. Note: `vim.pack.update()` will keep the plugin at the pinned revision; unpinning is a deliberate future edit.

**D2 — Keymap namespace: old scheme wins.** diffview takes the `<leader>gd*` group and neogit takes `<leader>gn/gc/gp/gP`. The two clashing gitsigns maps move: `diffthis` → `<leader>gD`, `preview_hunk` → `<leader>gv` (initially `<leader>gh`, moved again when the Octo GitHub tree claimed the `<leader>gh` prefix — the old config never had this clash because its gitsigns hunks lived under a separate `<leader>h` group, a restructuring that stays out of scope). Alternative (keep gitsigns, relocate new plugins) rejected per user decision — muscle memory follows the old config.

**D9 — Octo keymaps ported as a `<leader>gh` GitHub tree in `plugins/octo.lua`.** Subgroups mirror the old config: `ghi*` issues, `ghp*` PRs, `ghr*` reviews, `ghc*` comments, `ghR*` reactions, `gha*`/`ghl*` assignees/labels, `ghv*` reviewers, `ghn/ghs/ghd` notifications/search/discussions; `ghio`/`ghpo` prompt for a number via `vim.ui.input`. Old maps built on Snacks (`ghpd` PR-diff picker; the lazygit/gitbrowse set) are not ported — no Snacks in this config and lazygit already has its own module. The old `GitConflictListQf` maps (`gCQ` quickfix, `gCq` Trouble) come over into `plugins/git-conflict.lua` since Trouble is available.

**D3 — git-conflict uses explicit `default_mappings` table** exactly as in the old config (`<leader>gCo/gCt/gC0/gCb/gCn/gCp`) rather than the plugin's buffer-local defaults (`co`, `ct`, …), keeping all git actions discoverable under the `<leader>g` which-key tree.

**D4 — Module layout follows house style.** Four new files — `lua/plugins/diffview.lua`, `neogit.lua`, `octo.lua`, `git-conflict.lua` — each returning `M.setup()`, owning its plugin's keymaps, called from the Git section of `lua/plugins/init.lua` (after gitsigns/lazygit). `pack.lua` gains the four repos under the "Git & AI" section. Which-key group labels for `<leader>gd` (diffview) and `<leader>gC` (conflict) are registered in `whichkey.lua`, where all existing group labels live.

**D5 — Neogit config carried over as-is**: `kind = "floating"`, diffview + telescope integrations, old sign glyphs. Keymaps use `function() require("neogit").open(...) end` closures like the old spec.

**D6 — CopilotChat fix is opts-only.** Add to the existing `setup()` table:
```lua
mappings = {
  close = { normal = "q", insert = "" },
  show_diffs = { full_diff = true },
},
```
CopilotChat merges user mappings over defaults per-field, so other in-chat mappings keep their defaults.

**D7 — scope.nvim state rides auto-session hooks.** The old config saved/restored scope state through its session manager (`ScopeSaveState` in pre-save, `ScopeLoadState` in pre-restore). The current config's auto-session gains the same hooks (`pre_save_cmds` / `pre_restore_cmds`). `sessionoptions` already contains `tabpages,globals`, which scope's state (a session-persisted global) requires — no options change needed. Scope setup lives in a minimal `lua/plugins/scope.lua` module per house style.

**D8 — Tab keymaps are core keymaps, with two deliberate deviations from the old config.** They go in `lua/config/keymaps.lua` (they drive built-in `:tab*` commands, not a plugin) with the `<leader>j` group label in `whichkey.lua`. Deviations: (1) the old `gt`/`gT` → `<cmd>tabnext<cr>` remaps are dropped — they shadow the built-ins while destroying count support (`3gt` would no longer jump to tab 3); the built-ins already do exactly what the remaps did. (2) `<leader>js` ("open focused buffer in new tab") is implemented as capture-current-buffer → `tabnew` → set buffer, because the old `tabnew | BufferLineCyclePrev` trick depends on a shared buffer list and breaks under scope's per-tab scoping.

## Risks / Trade-offs

- [Pinned octo commit predates current CopilotChat/plenary versions] → The pin is exactly what the user runs successfully in the old config; if plenary drift ever breaks it, revisit the pin then. Comment documents why it exists.
- [Neogit `<leader>gc` may collide with a future "commit message" muscle memory (`<leader>gm` exists for Copilot commit gen)] → They're distinct keys; which-key descriptions disambiguate.
- [Eager `require("octo").setup()` adds startup cost vs. the old `cmd = "Octo"` lazy load] → Consistent with every other plugin in this config; octo's setup is cheap without opening a PR buffer. If startup cost shows up, defer via an `Octo` user command shim later.
- [git-conflict `version = "*"` in the old config pinned latest tag] → Use default branch like other plugins here; the plugin is stable. If a regression appears, pin a tag via `version`.
- [Remapped gitsigns keys break existing habit for `<leader>gd`/`<leader>gp`] → User explicitly chose this; which-key shows the new locations.

## Open Questions

None — the pin mechanism (D1) and keymap policy (D2) were resolved during explore.
