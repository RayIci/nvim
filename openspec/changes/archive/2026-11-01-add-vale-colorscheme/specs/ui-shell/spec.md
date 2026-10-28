# Spec Delta

## MODIFIED Requirements

### Requirement: Theme switcher with persistence
The configuration SHALL install catppuccin, tokyonight, kanagawa, gruvbox, rose-pine, nightfox, onedark, everforest, and nord, and provide a themery.nvim picker (`<leader>ut`) whose selection persists across restarts. The picker SHALL also list, at the top, every colorscheme defined by a file in the configuration's own `colors/` directory (such as the generated `vale-night` and `vale-day`), discovered at startup so that newly generated themes appear without editing the picker configuration. On first launch, when no selection has been persisted, `vale-night` SHALL be the active colorscheme. Themery's self-modifying block SHALL be confined to a dedicated small file.

#### Scenario: Theme persists
- **WHEN** the user selects kanagawa in the themery picker and restarts Neovim
- **THEN** kanagawa is the active colorscheme after restart

#### Scenario: Vale in the picker
- **WHEN** the user opens the themery picker
- **THEN** `vale-night` and `vale-day` are listed among the configuration's own colorschemes at the top, and selecting one applies it with live preview

#### Scenario: New theme appears without config edits
- **WHEN** a new colorscheme file `colors/ocean-night.lua` is added to the configuration and Neovim restarts
- **THEN** the themery picker lists `ocean-night` at the top, with no change to `lua/plugins/theme.lua`

#### Scenario: First-launch default
- **WHEN** Neovim starts with no persisted themery selection
- **THEN** `vale-night` is the active colorscheme

## ADDED Requirements

### Requirement: Theme-derived statusline labels and folder icons
Configuration outside the colorscheme SHALL NOT reference any specific colorscheme. The statusline's macro-recording, LSP-client, formatter and linter labels SHALL take their foreground from the active colorscheme's `DiagnosticError`, `DiagnosticInfo`, `DiagnosticOk` and `Statement` groups respectively, falling back to `#ff5555`, `#7aa2f7`, `#9ece6a` and `#bb9af7` when that group has no foreground. Neo-tree folder icons SHALL use the active colorscheme's `FolderIcon` group when it defines a foreground, and `#E5C07B` otherwise.

#### Scenario: Labels follow the theme
- **WHEN** the user switches from vale-night to kanagawa-wave without restarting
- **THEN** the LSP-client label shows kanagawa-wave's `DiagnosticInfo` colour

#### Scenario: Folder colour for third-party themes
- **WHEN** tokyonight-night is active
- **THEN** neo-tree folder icons are `#E5C07B`

#### Scenario: Folder colour from a theme that provides one
- **WHEN** vale-day is active
- **THEN** neo-tree folder icons use vale-day's `FolderIcon` colour
