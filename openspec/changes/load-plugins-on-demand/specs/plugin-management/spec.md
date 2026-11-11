# Spec Delta

## ADDED Requirements

### Requirement: Tools load on first use
The debug UI, the test runner and its adapters, the GitHub client, the diff viewer and project-wide find and replace SHALL NOT be loaded at startup. Each SHALL load on the first use of one of its keys or commands, and that first use SHALL behave exactly like later ones. Their keys and which-key entries SHALL exist from startup.

#### Scenario: First test run
- **WHEN** Neovim has just started in a Python project and the user presses `<leader>tr` in a test file
- **THEN** the nearest test runs, without a second key press or an error

#### Scenario: Keys visible before loading
- **WHEN** the user presses `<leader>g` before using any diff or GitHub command
- **THEN** which-key lists the `<leader>gd` and `<leader>gh` groups with their descriptions

## MODIFIED Requirements

### Requirement: Plugins are managed by native vim.pack
The configuration SHALL install every plugin through `vim.pack` from one installer in `lua/config/pack.lua`, with no third-party plugin manager, and SHALL be able to defer loading a plugin until it is first needed. Plugins with unstable APIs (nvim-treesitter `main`, blink.cmp) SHALL be pinned via the `version` field. Plugins with known-bad newer releases (octo.nvim) SHALL be pinned to a specific commit hash via the `version` field, with a comment explaining the reason for the pin.

#### Scenario: Fresh machine bootstrap
- **WHEN** Neovim is started for the first time on a machine with git installed
- **THEN** vim.pack clones all declared plugins, including those loaded later, and the editor loads without errors

#### Scenario: Reproducible plugin state
- **WHEN** `nvim-pack-lock.json` exists and plugins are updated with `target = 'lockfile'`
- **THEN** plugin working trees match the locked revisions

#### Scenario: Commit-pinned plugin stays put
- **WHEN** `vim.pack.update()` runs against a plugin whose `version` is a commit hash
- **THEN** the plugin remains at that commit rather than moving to the branch head
