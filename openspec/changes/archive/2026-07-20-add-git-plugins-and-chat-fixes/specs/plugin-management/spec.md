# plugin-management Delta

## MODIFIED Requirements

### Requirement: Plugins are managed by native vim.pack
The configuration SHALL install and load all plugins through a single `vim.pack.add()` declaration in `lua/config/pack.lua`, with no third-party plugin manager. Plugins with unstable APIs (nvim-treesitter `main`, blink.cmp) SHALL be pinned via the `version` field. Plugins with known-bad newer releases (octo.nvim) SHALL be pinned to a specific commit hash via the `version` field, with a comment explaining the reason for the pin.

#### Scenario: Fresh machine bootstrap
- **WHEN** Neovim is started for the first time on a machine with git installed
- **THEN** vim.pack clones all declared plugins and the editor loads without errors

#### Scenario: Reproducible plugin state
- **WHEN** `nvim-pack-lock.json` exists and plugins are updated with `target = 'lockfile'`
- **THEN** plugin working trees match the locked revisions

#### Scenario: Commit-pinned plugin stays put
- **WHEN** `vim.pack.update()` runs against a plugin whose `version` is a commit hash
- **THEN** the plugin remains at that commit rather than moving to the branch head
