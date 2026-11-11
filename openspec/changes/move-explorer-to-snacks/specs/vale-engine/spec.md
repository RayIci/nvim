# Spec Delta

## MODIFIED Requirements

### Requirement: Installed plugin integrations
Every generated colorscheme SHALL define the highlight groups of every UI-affecting plugin installed by the configuration. Each integration SHALL live in its own module. A group the engine defines SHALL still hold its defined value after all plugins' `ColorScheme` handlers have run.

#### Scenario: Diff readability
- **WHEN** a diff is shown in diffview
- **THEN** added, deleted, changed and changed-text regions are distinguishable from each other and the foreground text stays readable on each

#### Scenario: Plugins do not override
- **WHEN** any generated colorscheme is loaded with the full configuration
- **THEN** every highlight group the engine defines reads back with the engine's value

### Requirement: Required plugin integrations
Plugin integrations SHALL cover at least: gitsigns, diffview, git-conflict, snacks (picker, explorer, input, notifier, indent, words), bufferline, lualine, barbecue/navic, which-key, trouble, todo-comments, rainbow-delimiters, flash, blink.cmp, lightbulb, nvim-dap, nvim-dap-ui, nvim-dap-virtual-text, neotest, overseer, grug-far, render-markdown, toggleterm, nvim-ufo, multicursor, sidekick, mason, copilot, vim-dadbod-ui, easy-dotnet, kulala and agentdiff.

#### Scenario: Integration is present
- **WHEN** vale-night is active and the user opens a picker, the explorer, and a diffview
- **THEN** their windows, borders, selections and diff regions use vale-night colours, not colours linked from a previous theme or the Neovim default

#### Scenario: Agent review colours
- **WHEN** vale-night is active and a file shows pending agent changes
- **THEN** the overlay's removed lines, added lines, hint and conflict marks use vale-night colours

### Requirement: Folder icon hook
Every generated colorscheme SHALL define a `FolderIcon` highlight group with the theme's folder colour, so theme-agnostic configuration can pick up the folder colour without referencing vale.

#### Scenario: Folder colour under a generated theme
- **WHEN** vale-night is active and the explorer is open
- **THEN** folder icons use vale-night's folder colour
