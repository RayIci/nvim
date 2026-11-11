# Spec Delta

## ADDED Requirements

### Requirement: Persisted LSP display toggles
The code-action lightbulb (`<leader>ul`), global inlay hints (`<leader>li`) and code lenses (`<leader>lct`) SHALL each have a toggle whose state persists across restarts through the prefs module, applies immediately to every open buffer, and is listed under its which-key group. Defaults: lightbulb on, inlay hints off, code lenses on.

#### Scenario: Lightbulb off persists
- **WHEN** the user presses `<leader>ul` and restarts Neovim
- **THEN** no lightbulb sign appears on lines with code actions until `<leader>ul` is pressed again

#### Scenario: Inlay hints on persists
- **WHEN** the user turns inlay hints on with `<leader>li`, restarts, and opens a file whose server supports them
- **THEN** inlay hints are shown without pressing the key again

#### Scenario: Code lenses off persists across projects
- **WHEN** the user turns code lenses off with `<leader>lct` in one project and starts Neovim in another project
- **THEN** no code lenses are rendered there either

## MODIFIED Requirements

### Requirement: Diagnostics insert-mode refresh toggle
By default diagnostics SHALL appear on buffer open, on save, and after leaving insert mode, and diagnostic display defers insert-mode updates (`update_in_insert = false`). A toggle keymap (`<leader>ud`) SHALL switch diagnostic display to live refresh, updating in insert mode as servers publish, with the chosen state persisted across restarts through the prefs module and applied immediately. Linters SHALL NOT run while typing in either state.

#### Scenario: Diagnostics on open
- **WHEN** a file with existing lint findings is opened
- **THEN** its diagnostics appear without requiring a save

#### Scenario: Toggle to live refresh
- **WHEN** the user enables live diagnostics with the toggle keymap and types code introducing a type error reported by the language server
- **THEN** the diagnostic appears while still typing, without leaving insert mode or saving
- **AND** linter-only findings still appear after leaving insert mode

#### Scenario: Toggle persists
- **WHEN** the user enables live diagnostics and restarts Neovim
- **THEN** language-server diagnostics still refresh while typing until toggled back

#### Scenario: Default deferred refresh
- **WHEN** the toggle is off and the user introduces an error in insert mode
- **THEN** the diagnostic appears after returning to normal mode
