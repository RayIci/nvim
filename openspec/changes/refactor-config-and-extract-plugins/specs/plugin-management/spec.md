# Spec Delta

## ADDED Requirements

### Requirement: Plugin install specs live with their setup
Each plugin setup module SHALL declare the plugins it configures, and `lua/config/pack.lua` SHALL collect those declarations, plus the shared libraries and plugins that no single setup module owns, into its single `vim.pack.add()` call. Language-pack plugins keep being declared by their packs. Adding or removing a plugin SHALL take an edit to one setup module only, with no second list to keep in sync.

#### Scenario: Add a plugin in one place
- **WHEN** a new setup module declaring `owner/new.nvim` is added to the ordered module list and Neovim restarts
- **THEN** vim.pack installs `owner/new.nvim` and the module's setup runs, with no edit to `lua/config/pack.lua`

#### Scenario: Remove a plugin in one place
- **WHEN** a setup module is removed from the ordered module list
- **THEN** its plugins are no longer declared to vim.pack

#### Scenario: Shared dependency declared once
- **WHEN** several setup modules depend on a shared library such as plenary.nvim
- **THEN** that library is declared once, before any plugin that needs it is set up

### Requirement: Own plugins installed from their published repositories
The user's own plugins (agentdiff, commitsmith, git-worktree, vale) SHALL be installed by vim.pack from their public `RayIci/<name>.nvim` GitHub repositories and pinned in the lockfile like any other plugin. The configuration SHALL NOT load them from a local checkout by default; trying unpublished edits SHALL be possible by starting Neovim with that checkout prepended to `runtimepath`.

#### Scenario: Fresh machine
- **WHEN** Neovim starts on a machine without `~/Github` checkouts
- **THEN** all four plugins are cloned from GitHub and load without errors

#### Scenario: Try local edits
- **WHEN** the user starts `nvim --cmd 'set rtp^=~/Github/git-worktree.nvim'`
- **THEN** the local checkout's code is used instead of the installed copy, for that session only

## MODIFIED Requirements

### Requirement: Plugins are managed by native vim.pack
The configuration SHALL install and load all plugins through native `vim.pack`, with no third-party plugin manager: the core plugins through a single `vim.pack.add()` call made from `lua/config/pack.lua`, and language-pack plugins through the language-pack loader's own call. Plugins with unstable APIs (nvim-treesitter `main`, blink.cmp) SHALL be pinned via the `version` field. Plugins with known-bad newer releases (octo.nvim) SHALL be pinned to a specific commit hash via the `version` field, with a comment explaining the reason for the pin.

#### Scenario: Fresh machine bootstrap
- **WHEN** Neovim is started for the first time on a machine with git installed
- **THEN** vim.pack clones all declared plugins and the editor loads without errors

#### Scenario: Reproducible plugin state
- **WHEN** `nvim-pack-lock.json` exists and plugins are updated with `target = 'lockfile'`
- **THEN** plugin working trees match the locked revisions

#### Scenario: Commit-pinned plugin stays put
- **WHEN** `vim.pack.update()` runs against a plugin whose `version` is a commit hash
- **THEN** the plugin remains at that commit rather than moving to the branch head
