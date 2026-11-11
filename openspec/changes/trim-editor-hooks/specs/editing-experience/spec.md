# Spec Delta

## MODIFIED Requirements

### Requirement: Smart folding
The configuration SHALL fold code with LSP folding ranges when the attached server provides them, falling back to Tree-sitter folds when a parser is active and to indentation otherwise. Folds SHALL remain open when a buffer is opened, the editor SHALL show a small fold column with open/closed indicators, and `zR`, `zM`, `zr`, `zm` SHALL be Neovim's own fold commands, with `zU` closing the child folds of the fold under the cursor.

#### Scenario: File opens expanded
- **WHEN** a source file is opened
- **THEN** fold ranges are available for fold commands
- **AND** the file content is not automatically collapsed

#### Scenario: Folding provider fallback
- **WHEN** the attached LSP does not provide folding ranges for the current buffer
- **THEN** the configuration falls back to Tree-sitter or indentation-based folds instead of disabling folding entirely

#### Scenario: Provider-safe fold commands
- **WHEN** the user presses `zM` and then `zR` in a buffer, then opens another file
- **THEN** all folds close and reopen in that buffer, and the newly opened file starts with every fold open

### Requirement: Linting via nvim-lint
The configuration SHALL run nvim-lint, for filetypes with linters registered by language packs, when a buffer is opened, when it is entered, when insert mode is left, and when it is saved, publishing results as diagnostics. Entering a buffer or leaving insert mode SHALL NOT start a linter when the buffer is unchanged since its last lint, and linters SHALL NOT run while typing.

#### Scenario: Lint on save
- **WHEN** a file with a registered linter is written
- **THEN** linter findings appear as diagnostics in the buffer

#### Scenario: Lint after editing
- **WHEN** the user changes a line in insert mode and presses `<Esc>`
- **THEN** the buffer's linters run once

#### Scenario: Unchanged buffer is not re-linted
- **WHEN** the user enters insert mode and leaves it without typing, or switches back to a buffer that has not changed since it was linted
- **THEN** no linter process starts

#### Scenario: No lint while typing
- **WHEN** the user types several lines in insert mode
- **THEN** no linter process starts until insert mode is left or the buffer is saved
