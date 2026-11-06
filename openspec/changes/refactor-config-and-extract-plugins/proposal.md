# Proposal

## Why

The configuration has grown three plugin-sized subsystems that live in-tree (`lua/commitsmith/`, `lua/vale/`, and the git worktree workflow spread over `lua/plugins/worktrees.lua`, `lua/config/workspace.lua` and `lua/plugins/auto-session.lua`), plus duplicated persistence code and a few keymap and startup defects. The worktree workflow in particular is hard to maintain: its three files call into each other and into the private internals of five other plugins. agentdiff already showed the way out — a plugin in its own repository installed by `vim.pack`, with only host wiring left in the configuration — and this change applies that pattern to the remaining subsystems and cleans up what is left behind.

## What Changes

- **Extract commitsmith** into `~/Github/commitsmith.nvim` (published as `RayIci/commitsmith.nvim`, MIT). The configuration installs it with `vim.pack` and keeps only `lua/plugins/commitsmith.lua`. The one-time `seed` migration from the old Sidekick preference is removed (it has already run). Sidekick's fallback prompt comes from a public commitsmith function instead of the internal `commitsmith.prompt` module.
- **Extract the worktree workflow** into a new plugin `~/Github/git-worktree.nvim` (`RayIci/git-worktree.nvim`, MIT), redesigned around a plain-git core and a switch protocol (check → pause → flush → save session → reset → change directory → restore → resume, with rollback). Neogit, auto-session, nvim-dap, scope.nvim, bufferline and neo-tree become optional integration modules, not hard dependencies. Neogit no longer performs the git mutations; plenary is no longer required. The configuration keeps the keymaps, the which-key group, the Neogit `w` entry point, and its own workspace persistence, which registers with the plugin as a participant.
- **Extract vale** (theme engine + studio) into `~/Github/vale.nvim` (`RayIci/vale.nvim`, MIT). The bundled `vale` theme and its colorscheme/lualine loaders ship with the plugin and are read-only (studio edits copy them into the user's themes directory first). User themes (`themes/vale-starter`) and the loaders the studio generates for them stay in the configuration.
- **Co-locate plugin install specs**: each `lua/plugins/<name>.lua` declares the plugins it sets up; `lua/config/pack.lua` collects them (plus shared libraries no single module owns) into its single `vim.pack.add()` call. The PackChanged build-hook wiring that `pack.lua` and the language-pack loader each implement becomes one shared installer.
- **Shared persistence helper** `lua/config/state.lua` (JSON store, per-project state path, debounced saver with pause/resume/flush/generation) replaces the four JSON read/write copies and the two identical debounce implementations.
- **Workspace persistence split by concern**: `lua/config/workspace.lua` becomes the `lua/config/workspace/` package (buffers, breakpoints, pins, explorer, scope); `lua/plugins/auto-session.lua` shrinks to auto-session setup and its keymaps.
- **Keymap fixes**: multicursor's line/rotate keys move to `<M-Up/Down/Left/Right>` so they no longer collide with window resize on `<C-arrows>` in normal mode (which silently disabled them). The README documents unbinding Alt+arrows in terminals that use them (Windows Terminal, Ghostty, Konsole, iTerm2, Terminal.app, tmux).
- **Small fixes**: remove the duplicated `require("config.options")` and comment in `init.lua`; fix the misplaced "below" comment in `lua/config/keymaps.lua`.
- **Housekeeping**: archive the completed `add-git-worktree-workspaces` change first (its requirements are partly moved out by this change). The in-progress `add-agentdiff-plugin` change and the remote `main-worktree` branch are left alone.

## Capabilities

### New Capabilities

None in this configuration. Each extracted plugin gets its own `openspec/` in its repository, seeded from the requirements this change removes here: `commit-message-ai` → commitsmith.nvim, the worktree management and transition requirements → git-worktree.nvim (as a new `worktree-workspaces` capability), `vale-engine` and `vale-studio` → vale.nvim. Further changes to those behaviours are planned in those repositories.

### Modified Capabilities

- `commit-message-ai`: all requirements removed from this configuration; they move to the commitsmith.nvim repository.
- `vale-engine`: all requirements removed; they move to vale.nvim (amended there for bundled read-only themes and a configurable user themes directory).
- `vale-studio`: all requirements removed; they move to vale.nvim.
- `git-integration`: the commit-message wiring installs the published plugin; the worktree creation/destination/deletion requirements move to git-worktree.nvim; a new worktree plugin wiring requirement replaces "Managed worktree actions".
- `ui-shell`: the worktree switching, unsaved-edit guard, live-resource guard and failure-recovery requirements move to git-worktree.nvim; workspace persistence isolation is restated as the configuration's participant contract; the theme picker also lists colorschemes provided by the vale plugin; a vale plugin wiring requirement is added.
- `editing-experience`: multicursor line and rotation keys move to `<M-arrows>`.
- `core-keymaps`: window resize on `<C-arrows>` becomes a specified core keymap.
- `plugin-management`: install specs are declared per plugin module and collected by `pack.lua`; the user's own plugins are installed from their published GitHub repositories.

## Impact

- **New repositories**: `~/Github/commitsmith.nvim`, `~/Github/git-worktree.nvim`, `~/Github/vale.nvim`, each with README, `doc/<name>.txt`, MIT `LICENSE`, `Makefile`, a dependency-free headless test runner, `.stylua.toml`, and `openspec/`. Publishing them on GitHub is outward-facing and is confirmed with the user at that step.
- **Removed from the config**: `lua/commitsmith/`, `lua/vale/`, `colors/vale-day.lua`, `colors/vale-night.lua`, `lua/lualine/themes/vale-day.lua`, `lua/lualine/themes/vale-night.lua`, `themes/vale/`, `lua/plugins/worktrees.lua`, `lua/config/workspace.lua` (replaced by a package of the same module name), `tests/worktrees.lua`, `tests/worktree-startup.lua` (moved or replaced).
- **New in the config**: `lua/config/state.lua`, `lua/config/workspace/`, `lua/plugins/git-worktree.lua`, `lua/plugins/vale.lua`, and a smaller config-side test for the workspace participant.
- **Touched**: `init.lua`, `lua/config/pack.lua`, `lua/plugins/init.lua`, every `lua/plugins/*.lua` (spec field), `lua/plugins/auto-session.lua`, `lua/plugins/bufferline.lua`, `lua/plugins/neogit.lua`, `lua/plugins/sidekick.lua`, `lua/plugins/theme.lua`, `lua/plugins/visual-multi.lua`, `lua/langs/init.lua`, `lua/config/keymaps.lua`, `lua/config/prefs.lua`, `nvim-pack-lock.json`, `README.md`.
- **Unchanged on disk**: state files keep their locations (`stdpath("state")/workspaces/`, `stdpath("state")/neotree/`, `stdpath("state")/prefs.json`, `stdpath("data")/commitsmith/settings.json`, auto-session's session directory), so existing sessions, pins, breakpoints and settings carry over.
- **Behaviour**: unchanged apart from the multicursor keys; plenary stops being a worktree dependency. Local development of an extracted plugin uses `nvim --cmd 'set rtp^=~/Github/<name>.nvim'`, as for agentdiff.
