# Spec Delta

## ADDED Requirements

### Requirement: Window resize with Ctrl-arrows
In normal mode, `<C-Up>`/`<C-Down>` SHALL grow/shrink the current window's height by 2 lines and `<C-Left>`/`<C-Right>` SHALL shrink/grow its width by 2 columns. No other configured mapping SHALL claim these keys in normal mode.

#### Scenario: Resize a split
- **WHEN** the editor has two vertical splits and the user presses `<C-Right>` in the left one
- **THEN** the left window becomes 2 columns wider

#### Scenario: Resize is not shadowed
- **WHEN** Neovim has finished starting and the user inspects the normal-mode mapping of `<C-Up>`
- **THEN** it is the window-resize mapping, not a multicursor action
