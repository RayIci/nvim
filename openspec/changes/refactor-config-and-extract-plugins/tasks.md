# Tasks

## 1. Preparation

- [x] 1.1 Create the working branch `refactor-config-and-extract-plugins` from `main` and verify `git status` is clean and `main` contains `c2f64ab`
- [x] 1.2 Archive `add-git-worktree-workspaces` with `openspec archive add-git-worktree-workspaces` and verify its requirements now appear in `openspec/specs/git-integration/spec.md` and `openspec/specs/ui-shell/spec.md`, and that `openspec validate refactor-config-and-extract-plugins --strict` no longer reports the `ui-shell` header as not found
- [x] 1.3 Record a baseline: run `nvim --headless -u NONE -l tests/worktrees.lua` and a plain headless startup (`nvim --headless +qa`) and verify both pass, so later groups can be compared against it

## 2. Startup and keymap fixes

- [x] 2.1 Remove the duplicated `require("config.options")` and the duplicated "Entry point" comment from `init.lua`; verify options load once and headless startup shows no errors
- [x] 2.2 Move multicursor's add-cursor keys to `<C-S-Up>`/`<C-S-Down>` and rotate keys to `<C-S-Left>`/`<C-S-Right>` in `lua/plugins/visual-multi.lua` (header comment included), keeping resize on `<C-arrows>` in `lua/config/keymaps.lua`; verify with `:verbose nmap <C-Up>` (resize) and `:verbose nmap <C-S-Up>` (multicursor) in a headless check
- [x] 2.3 Fix the misplaced "(alongside <Esc> below)" comment in `lua/config/keymaps.lua`; verify the comment matches the mapping order
- [x] 2.4 Update the README key-binding table for the multicursor keys and add the Windows Terminal note (unbind `ctrl+shift+up`/`ctrl+shift+down` with `"id": null`, verify with `<C-v>` in insert mode); verify every documented key exists

## 3. One installer and per-module install specs

- [x] 3.1 Add `install(specs)` to `lua/config/pack.lua` (shorthand expansion, PackChanged build hooks, one `vim.pack.add(..., { confirm = false })`) and use it from `lua/langs/init.lua` in place of its own build-hook wiring; verify a headless startup installs nothing new and `telescope-fzf-native` and language-pack build hooks are still registered
- [x] 3.2 Make `lua/plugins/init.lua` export the ordered module list and a `setup()`; give every `lua/plugins/*.lua` module an `M.spec` with the plugins it configures (themes and themery in `plugins/theme.lua`, promise-async in `plugins/folding.lua`, and so on) and keep only shared libraries and vim-tmux-navigator in `pack.lua`; verify the set of declared plugins is identical before and after (compare the sorted `src` lists) and `nvim-pack-lock.json` is unchanged
- [x] 3.3 Add a headless check that loads every `lua/plugins/*.lua` module with only the config on `runtimepath` and fails on any error; verify it passes and fails when a top-level plugin `require` is introduced
- [x] 3.4 Update the README "Plugin updates" and layout sections to describe where install specs live; verify the described steps for adding a plugin work on a throwaway module

## 4. State helper and workspace package

- [x] 4.1 Add `lua/config/state.lua` (`path`, `read`, `write`, `saver`) keeping the existing key function byte-for-byte; verify with a headless test that it reads files written in the current format, distinguishes missing from empty, and that the saver's late callbacks never write after `pause`, a cwd change or a generation bump
- [x] 4.2 Port `lua/config/prefs.lua` to `config.state`; verify the rainbow toggle and SQL/conform/lsp preferences persist across a restart with the existing `prefs.json`
- [x] 4.3 Replace `lua/config/workspace.lua` with the `lua/config/workspace/` package (`init`, `buffers`, `breakpoints`, `pins`, `explorer`, `scope`), moving the neo-tree, pins and scope persistence out of `lua/plugins/auto-session.lua` and using `config.state` throughout; verify `tests/worktrees.lua` still passes unchanged apart from require paths
- [ ] 4.4 Reduce `lua/plugins/auto-session.lua` to auto-session setup (hooks pointing at `config.workspace`) and the `<leader>q` keymaps, and point `lua/plugins/bufferline.lua` at `config.workspace`; verify the session round-trip, pins, breakpoints and neo-tree restore after a normal quit and after `:restart`
- [ ] 4.5 Update the README "Workspace persistence" section for the new module layout; verify the state file locations it lists match what the code writes

## 5. commitsmith.nvim

- [ ] 5.1 Create `~/Github/commitsmith.nvim` from the agentdiff template (README, `doc/commitsmith.txt`, MIT `LICENSE`, `Makefile`, `tests/run.lua`, `.stylua.toml`, `.luarc.json`, `.gitignore`) and move `lua/commitsmith/` into it; verify `make fmt-check` and `make helptags` succeed
- [ ] 5.2 Remove the `seed` option and `settings.seed()`, and add the public `fallback_prompt()`; verify with tests that both prompts carry the shared rules, settings are re-read on each access, a missing harness errors without fallback, and generation outside a commit buffer calls the fallback or reports the no-fallback error (`make test`)
- [ ] 5.3 Initialise `openspec/` in the repository and seed `openspec/specs/commit-message-ai/spec.md` from this config's spec (wording adapted to the plugin); verify `openspec validate --specs --strict` passes there
- [ ] 5.4 Point `lua/plugins/commitsmith.lua` (no `seed`) and `lua/plugins/sidekick.lua` (`fallback_prompt()`) at the public API and run the config with `--cmd 'set rtp^=~/Github/commitsmith.nvim'` with `lua/commitsmith/` moved aside; verify `<leader>am`, `<leader>aM`, `<leader>ac` and the Sidekick fallback work and existing settings are kept
- [ ] 5.5 Review the repository for personal paths, tokens or work data, then (after the user confirms) create and push `RayIci/commitsmith.nvim` as a public repository; verify `gh repo view RayIci/commitsmith.nvim` shows it public with the pushed commit
- [ ] 5.6 Add `RayIci/commitsmith.nvim` to the commitsmith module's spec, delete `lua/commitsmith/`, let vim.pack install it and update the README commit-message section; verify a headless startup with no local override loads the published plugin and the lockfile has its revision

## 6. git-worktree.nvim

- [ ] 6.1 Create `~/Github/git-worktree.nvim` from the template with `lua/git-worktree/` (`init`, `git`, `path`, `ui`, `switch`), porting discovery, branch listing, destination rules, creation and removal to plain `git` via `vim.system`; verify core specs for porcelain parsing (detached, spaces, aliases), destinations and create/remove against temporary repositories pass with `-u NONE`
- [ ] 6.2 Implement the switch transaction over participants and an optional session backend (check, pause, flush, reset, cleanup, cd, restore, resume, rollback, busy guard, `User` events), with the coroutine helper replacing plenary; verify with fake participants and a fake backend that phase order, abort-before-teardown on save failure, rollback, paused writes after failed recovery, the active-checkout no-op and the busy refusal all behave as specified
- [ ] 6.3 Add the integrations `auto_session` (session backend), `neogit`, `dap`, `scope`, `bufferline` and `neotree`, each skipped with one warning when its plugin is missing; verify `tests/integration/` against the plugins on `packpath` (`make test-integration`) covers the cases from `tests/worktrees.lua` that need real plugins, and that the core suite still passes with none installed
- [ ] 6.4 Write the README and `doc/git-worktree.txt` (setup options, participant interface, events, integrations, destination rule, safeguards, raw `:Neogit worktree` boundary) and seed `openspec/specs/worktree-workspaces/spec.md` from the requirements this change removes; verify `openspec validate --specs --strict` passes and every documented option exists
- [ ] 6.5 Add `lua/plugins/git-worktree.lua` (integration list, `<leader>gww`/`gwc`/`gwd`, `register` of the `config.workspace` participant), point Neogit's status `w` at `require("git-worktree").menu()`, delete `lua/plugins/worktrees.lua`, and run with `--cmd 'set rtp^=~/Github/git-worktree.nvim'`; verify in a disposable repository: create with the default and an override, create from a linked checkout, switch A→B→A with distinct layouts/pins/breakpoints/explorer state, remove a clean inactive worktree, via both the leader keys and Neogit `w`
- [ ] 6.6 Replace `tests/worktrees.lua` and `tests/worktree-startup.lua` with `tests/workspace.lua` and `tests/workspace-startup.lua` covering the participant (round-trip, empty vs missing snapshots, late callbacks, `:restart` reconciliation, startup with and without file arguments); verify every case of the old suite exists in either the plugin or the config tests and all pass
- [ ] 6.7 Review, then (after the user confirms) create and push `RayIci/git-worktree.nvim` as public; add it to the module's spec, update the README "Git worktree workspaces" section and the lockfile; verify a headless startup with no local override loads the published plugin and plenary is no longer needed by it

## 7. vale.nvim

- [ ] 7.1 Create `~/Github/vale.nvim` from the template and move `lua/vale/` (engine, groups, integrations, studio and assets), `themes/vale/`, `colors/vale-{night,day}.lua` and `lua/lualine/themes/vale-{night,day}.lua` into it; verify `:colorscheme vale-night` and `vale-day` load from the repository with `--cmd 'set rtp^=…'`
- [ ] 7.2 Add `setup({ themes_dir, output_dir })` (defaults in the config directory), user-before-bundled lookup, copy-on-edit for bundled themes and `colorschemes()`; verify tests for load/background/`colors_name`, role layering, user-over-bundled precedence, de-duplicated listing, copy-on-edit leaving the install directory untouched, and byte-preserving writer edits (`make test`)
- [ ] 7.3 Write the README and `doc/vale.txt`, and seed `openspec/specs/vale-engine/spec.md` and `openspec/specs/vale-studio/spec.md` (amended for bundled read-only themes and configurable directories); verify `openspec validate --specs --strict` passes
- [ ] 7.4 Add `lua/plugins/vale.lua` (vale and studio setup moved out of `plugins/theme.lua`) and make the theme picker use `require("vale").colorschemes()` plus the config's `colors/`; verify `vale-night`, `vale-day` and `vale-starter-night` each appear once, `vale-starter-night` still loads from `themes/vale-starter/`, a theme created in the studio is written into the config, and the persisted themery selection still applies on restart
- [ ] 7.5 Review, then (after the user confirms) create and push `RayIci/vale.nvim` as public; add it to the module's spec, delete the moved files from the config, update the README theme notes and the lockfile; verify a headless startup with no local override loads the published plugin and no `lua/vale/` remains in the config

## 8. Integration checks

- [ ] 8.1 Fresh-machine check: start Neovim with empty temporary `XDG_DATA_HOME`/`XDG_STATE_HOME` and verify all plugins, including agentdiff, commitsmith, git-worktree and vale, are cloned from GitHub and startup has no errors
- [ ] 8.2 Continuity check with the real state directories: verify existing sessions, pins, breakpoints, neo-tree state, prefs, commitsmith settings and the themery selection all survive the refactor
- [ ] 8.3 Run `stylua --check` over the config and each plugin's `make fmt-check` and `make test`, and `openspec validate refactor-config-and-extract-plugins --strict`; verify all pass

## Workflow follow-up

- The user checks the `<C-S-arrows>` multicursor keys through Windows Terminal after unbinding its defaults.
- Archive `refactor-config-and-extract-plugins`, then delete the main spec files left with no requirements (`openspec/specs/commit-message-ai/`, `openspec/specs/vale-engine/`, `openspec/specs/vale-studio/`).
- `add-agentdiff-plugin` and the remote `main-worktree` branch stay untouched.
