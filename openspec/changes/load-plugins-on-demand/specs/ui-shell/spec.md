# Spec Delta

## ADDED Requirements

### Requirement: Themes load when chosen
At startup only the active colorscheme's plugin SHALL be on the runtimepath. Selecting or live-previewing a theme in the `<leader>ut` picker SHALL load that theme's plugin first, so every listed theme previews and applies as before, and the persisted selection SHALL be restored on the next start.

#### Scenario: Only the active theme is loaded
- **WHEN** Neovim starts with kanagawa-wave persisted as the theme
- **THEN** the kanagawa plugin is on the runtimepath and the tokyonight, catppuccin and other theme plugins are not

#### Scenario: Previewing an unloaded theme
- **WHEN** the user opens the theme picker and moves to "Tokyonight Storm"
- **THEN** the theme previews immediately, and selecting it persists it for the next start
