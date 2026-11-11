# Design

## Context

See proposal.md for motivation. Current state that shapes the approach:

- **agentdiff is the template.** `~/Github/agentdiff.nvim` has `lua/`, `doc/`, `tests/run.lua` (dependency-free headless runner), `Makefile` (`test`, `fmt`, `fmt-check`, `helptags`), `.stylua.toml`, `.luarc.json`, `openspec/`, and is installed with `gh("RayIci/agentdiff.nvim")`; the config keeps only `lua/plugins/agentdiff.lua`. Unpublished edits are tried with `--cmd 'set rtp^=~/Github/agentdiff.nvim'`.
- **commitsmith** (`lua/commitsmith/`, 12 files) requires nothing outside itself. Its only external users are `lua/plugins/commitsmith.lua` and `lua/plugins/sidekick.lua`, which reaches into the internal `commitsmith.prompt`. The `seed` option exists only for a one-time migration that has already run (`stdpath("data")/commitsmith/settings.json` exists; `prefs.json` no longer has the old key).
- **vale** (`lua/vale/`) requires nothing outside itself, but reads themes from `stdpath("config")/themes` and the studio writes loaders into `stdpath("config")/colors` and `stdpath("config")/lua/lualine/themes`. `lua/plugins/theme.lua` scans the config's `colors/` for the picker and calls `require("vale.studio").setup()`.
- **The worktree workflow** spans `lua/plugins/worktrees.lua` (git, pickers, switch transaction), `lua/config/workspace.lua` (mutation-time persistence of breakpoints, buffers, pins) and `lua/plugins/auto-session.lua` (auto-session setup plus neo-tree/scope/bufferline persistence and reset). The switch reaches into neogit internals (`neogit.lib.git.repository`, `neogit.lib.git` cli, `neogit.buffers.status`), auto-session's config table, `scope.core`, `bufferline.groups`, `neo-tree.sources.manager` and `dap.breakpoints`, and uses `plenary.async` only to await `vim.ui.select`/`vim.ui.input`. `tests/worktrees.lua` (1088 lines) and `tests/worktree-startup.lua` exercise all of it against the installed plugins.
- **Duplicated persistence code**: the per-project key (`cwd:gsub("[/\\:]", "%%")`), the debounced saver (timer + `exiting`/`paused`/`generation` + `pause`/`resume`/`flush`) and JSON read/write appear in both `config/workspace.lua` and `plugins/auto-session.lua`; JSON read/write again in `config/prefs.lua`; the scope-cache walk twice inside `config/workspace.lua`. The PackChanged build-hook wiring is implemented in both `config/pack.lua` and `langs/init.lua`.
- `add-git-worktree-workspaces` is complete but not archived, so the worktree requirements this change removes or modifies are not yet in the main specs (validation reports the `ui-shell` MODIFIED header as not found until then).
- No `lua/plugins/*.lua` module requires a plugin at the top level, so the modules can be loaded before `vim.pack.add()` to read their install specs.

## Goals / Non-Goals

**Goals:**
- Three plugin repositories that work standalone (no reference to this config) and stay small to maintain.
- git-worktree's core depends on nothing but Neovim and git; every other plugin it cooperates with is an optional integration.
- The config after extraction has one place per concern: one installer, one state helper, one module per persistence concern.
- Existing state files, sessions, settings and the persisted theme selection keep working with no migration step.

**Non-Goals:**
- No behaviour changes beyond the multicursor keys and the vale bundled-theme rules; the moved requirements are carried over as they are.
- No CI, releases or tags for the new repositories; the lockfile pins revisions.
- No changes to agentdiff or to the `add-agentdiff-plugin` change.
- No attempt to intercept Neogit's raw `:Neogit worktree` popup (unchanged boundary from the original design).

## Decisions

### 1. Repository template shared by all three plugins
Each repository copies agentdiff's layout: `lua/<module>/`, `doc/<name>.txt`, `README.md`, MIT `LICENSE` (copyright Alex Valle), `Makefile`, `tests/run.lua` + `tests/*_spec.lua`, `.stylua.toml`, `.luarc.json`, `.gitignore`, and `openspec/` (initialised with `openspec init`, main specs seeded from the requirements this change removes, wording adapted from "the configuration" to "the plugin"). Module names stay `commitsmith`, `vale` and `git-worktree` (`require("git-worktree")`), so nothing in the config changes its require paths except the worktree host module.
*Alternative*: a monorepo of plugins — rejected; vim.pack installs one repository per plugin, and agentdiff already set the one-repo pattern.

### 2. Development and publishing order per plugin
Build and test in `~/Github/<name>.nvim` with the config loading it through `--cmd 'set rtp^=…'`, then (after the user confirms) create the public GitHub repository with `gh repo create RayIci/<name>.nvim --public --source . --push`, then add the spec to the config, remove the in-tree copy, and let vim.pack record the revision in `nvim-pack-lock.json`. The in-tree copy is removed in the same commit that adds the spec, so there is never a moment with two copies on `runtimepath`.

### 3. commitsmith: public prompt, no seed
`require("commitsmith").fallback_prompt()` becomes the public entry point that `plugins/sidekick.lua` uses; `commitsmith.prompt` stays internal. The `seed` option, `settings.seed()` and the host's `seed` callback are deleted. The settings file location is unchanged. Tests cover the parts that need no harness: shared Conventional Commits rules in both prompts, settings re-read from disk on each access, missing-harness error, subcommand buffer requirements, fallback dispatch and the no-fallback error.

### 4. git-worktree: plain-git core plus a switch protocol
```
lua/git-worktree/
  init.lua      setup(opts), create/switch/delete/menu, register(participant)
  git.lua       vim.system argument arrays: list --porcelain -z, branches, add, remove, status
  path.lua      destination rule <main>.worktrees/<branch>, overrides, validation
  ui.lua        pickers and prompts over vim.ui.select/input (awaited with a small coroutine helper)
  switch.lua    the transaction below, busy guard, rollback
  integrations/ auto_session neogit dap scope bufferline neotree
```
The switch transaction keeps the current order and failure handling, expressed over participants:
```
check     core: modified buffers (save-all or cancel), live terminal jobs; participants: check()
pause     every participant pause(); session backend stops autosave
flush     every participant flush(source); session backend save(source)  -- failure aborts, nothing torn down
reset     participants reset()  ->  core: blank buffer, tabonly, only, delete buffers  ->  participants cleanup()
cd        nvim_set_current_dir(target); session backend restore(target) when one exists
restore   every participant restore(target)
resume    every participant resume(); session backend restores autosave; User GitWorktreeSwitched
failure after reset: reset again, cd source, restore source session + participants; if that fails too,
                     keep writes paused and report both errors with the current cwd and source session
```
A participant is a table with optional `check`, `pause`, `flush`, `reset`, `cleanup`, `restore`, `resume` functions and a `name`. Integrations are participants the plugin ships; `setup({ integrations = { "auto_session", "neogit", "dap", "scope", "bufferline", "neotree" } })` enables them (each is skipped with a single warning if its plugin is not installed). The config registers its workspace persistence with `register()`.
The auto-session integration is the **session backend** (save/exists/restore per cwd, temporarily disabling autosave and turning restore errors into failures, as the current code does with auto-session's config table). With no backend, a switch still resets and restores participants.
The plugin fires `User` events `GitWorktreeCreated`, `GitWorktreeRemoved`, `GitWorktreeSwitchPre` and `GitWorktreeSwitched` with `data = { path = … }`.
*Alternatives*: keep running mutations through Neogit (the original decision 1) — rejected because Neogit would become a hard dependency of the plugin; the Neogit integration instead closes the status float before an action and rebinds/refreshes Neogit's repository after `GitWorktreeCreated`/`Removed`/`Switched`, which preserves the reason for the original decision. A single monolithic `on_switch` callback — rejected; the ordered phases are what make rollback and stale-callback protection possible.

### 5. Config side of the worktree workflow
- `lua/plugins/git-worktree.lua`: `setup` with the integration list, the `<leader>gw*` keymaps, and `register(require("config.workspace").participant)`.
- `lua/plugins/neogit.lua`: status `w` calls `require("git-worktree").menu()`.
- `lua/config/workspace/` replaces `config/workspace.lua` under the same module name: `init.lua` (setup, the participant, `touch`, the auto-session hook functions), `buffers.lua`, `breakpoints.lua`, `pins.lua`, `explorer.lua` (neo-tree snapshot/restore, foreign-buffer wipe), `scope.lua` (scope state in `vim.g.ScopeState`). The participant's `pause`/`flush`/`restore`/`resume` drive all of them; resets of neo-tree, bufferline groups, the scope cache and breakpoints come from the plugin's integrations, so the config never duplicates them.
- `lua/plugins/auto-session.lua` keeps only `require("auto-session").setup()` (with `pre_save_cmds`/`pre_restore_cmds`/`post_restore_cmds` pointing at `config.workspace` functions) and the `<leader>q` keymaps.

### 6. One state helper
`lua/config/state.lua` provides: `path(kind, cwd)` → `stdpath("state")/<kind>/<key>.json` using the existing key function byte-for-byte; `read(path, default)` / `write(path, value)` (missing file → default, existing-but-invalid → error, so "empty" and "missing" stay distinct); and `saver({ delay, save })` returning `touch`/`pause`/`resume`/`flush`/`exit`, with the cwd-and-generation guard the two current implementations share. `config/prefs.lua` and every `config/workspace/*` module use it. Existing files under `workspaces/`, `neotree/` and `prefs.json` are read unchanged.

### 7. Co-located install specs and one installer
`lua/plugins/init.lua` exports the ordered module list and a `setup()` that runs each module's `setup`. Each module may set `M.spec` to a list of entries in the existing `LangPackPlugin` shape (`src`, `name`, `version`, `build`). `lua/config/pack.lua` exposes `install(specs)` (GitHub shorthand expansion, PackChanged build hooks, one `vim.pack.add(..., { confirm = false })`), collects the shared libraries (plenary, nui, devicons, nvim-nio) and the one plugin no setup module owns (vim-tmux-navigator, whose keymaps live in `config/keymaps.lua` because they must be defined before its script is sourced), followed by every module's `spec`; single-owner dependencies such as promise-async (nvim-ufo) move into their owner's spec, and installs them. `langs/init.lua` calls the same `install`. Colorscheme packages and themery move to `plugins/theme.lua`'s spec.
*Alternative*: keep the central list in `pack.lua` — rejected by the user's choice to make plugins self-describing; the language packs already work this way.

### 8. vale: bundled themes are read-only, user themes stay in the config
The plugin ships `themes/vale/` plus `colors/vale-{night,day}.lua` and `lua/lualine/themes/vale-{night,day}.lua`. `setup({ themes_dir, output_dir })` defaults both to `stdpath("config")` (`themes/`, and `colors/` + `lua/lualine/themes/`). Theme lookup checks the user directory first, then the bundled one, so a user copy of `vale` wins and is listed once. Opening a bundled theme in the studio editor copies its files into the user `themes/` before the first edit; the bundled loaders already resolve the user copy, so no extra loaders are generated for it. `require("vale").colorschemes()` lists bundled and user colorschemes de-duplicated; `plugins/theme.lua` uses it together with the config's `colors/` files. `lua/plugins/vale.lua` calls `require("vale").setup()` and the studio setup, moved out of `plugins/theme.lua`. `themes/vale-starter/` and its loaders stay in the config. Tests cover load/background/`colors_name`, role layering, user-over-bundled precedence, `colorschemes()` de-duplication, and the writer's byte-preserving single-line edits.

### 9. Keymaps
`plugins/visual-multi.lua` binds `<M-Up/Down>` (add cursor) and `<M-Left/Right>` (rotate) in normal and visual mode; `config/keymaps.lua` keeps resize on `<C-arrows>` in normal mode. `<C-S-arrows>` were tried first but did not reach Neovim through Windows Terminal and tmux. The README gives copy-paste snippets for unbinding Alt+arrows per terminal (Windows Terminal moves pane focus with them by default) and a `<C-v>` check in insert mode.

### 10. Test split
- `git-worktree.nvim/tests/`: core specs that run with `-u NONE` and no plugins (porcelain parsing, destinations, create/remove against temporary repositories, preflight, the transaction with fake participants and a fake session backend, rollback, busy guard), plus `tests/integration/` that uses real auto-session, scope, bufferline, neo-tree, nvim-dap and neogit found on `packpath` and is skipped with a notice when they are missing (`make test-integration`).
- Config: `tests/workspace.lua` covers the participant against the real plugins (A→B→A round-trip, empty-vs-missing snapshots, late callbacks, `:restart` reconciliation), and `tests/workspace-startup.lua` replaces `worktree-startup.lua` for real startup with and without file arguments. The cases from `tests/worktrees.lua` are distributed between these, none dropped.

## Risks / Trade-offs

- [Neogit's private repository API changes on update] → Only `integrations/neogit.lua` touches it, each call is guarded, and the integration suite runs against the locked revision.
- [Loading `plugins/*.lua` before `vim.pack.add()` breaks if a module later gains a top-level `require` of a plugin] → A headless check loads every module with only the config on `runtimepath` and fails on any error.
- [A terminal keeps Alt+arrows for itself] → Per-terminal unbind snippets and a `<C-v>` check in the README.
- [`require("git-worktree")` matches ThePrimeagen's git-worktree.nvim module] → Accepted by the user; only matters if both are installed.
- [Publishing exposes code publicly] → Each repository's contents are reviewed for personal paths, tokens or work data before the user confirms creation.
- [State continuity] → The key function and paths are kept byte-for-byte, and the config tests start from fixture files written in the current format.
- [A large change in one OpenSpec change] → Tasks are grouped so each group ends in a working, committed state; the config never depends on an unpublished plugin.

## Migration Plan

1. Archive `add-git-worktree-workspaces` so its requirements are in the main specs.
2. Config refactor (installer, specs per module, state helper, `config/workspace/` package, auto-session slimming, keymaps, `init.lua`): behaviour-preserving, verified by the existing worktree tests before anything moves out.
3. commitsmith, then git-worktree, then vale: for each, build the repository, test, review, publish (user confirms), switch the config to the published plugin, delete the in-tree copy, update the lockfile and README.
4. Archive this change; delete the main spec files left with no requirements (`commit-message-ai`, `vale-engine`, `vale-studio`).

Rollback: each step is its own commit on the config; reverting the commit that switched to a published plugin restores the in-tree copy. The plugin repositories need no rollback.
