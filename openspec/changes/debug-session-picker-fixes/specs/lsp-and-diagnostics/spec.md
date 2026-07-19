# lsp-and-diagnostics Delta

## MODIFIED Requirements

### Requirement: Diagnostics insert-mode refresh toggle
By default diagnostics SHALL appear on buffer open, on save, and after leaving insert mode: linters run on `BufReadPost`/`BufWritePost`/`InsertLeave` and diagnostic display defers insert-mode updates (`update_in_insert = false`). A toggle keymap SHALL switch to live refresh — diagnostic display updates in insert mode AND linters run debounced on every text change — with the chosen state persisted across restarts through the prefs module and applied immediately without restart.

#### Scenario: Diagnostics on open
- **WHEN** a file with existing lint findings is opened
- **THEN** its diagnostics appear without requiring a save

#### Scenario: Toggle to live refresh
- **WHEN** the user enables live diagnostics with the toggle keymap and types code introducing a lint error
- **THEN** the diagnostic appears while still typing, without leaving insert mode or saving

#### Scenario: Toggle persists
- **WHEN** the user enables live diagnostics and restarts Neovim
- **THEN** diagnostics still refresh while typing until toggled back

#### Scenario: Default deferred refresh
- **WHEN** the toggle is off and the user introduces an error in insert mode
- **THEN** the diagnostic appears after returning to normal mode
