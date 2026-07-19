# editing-experience Delta

## MODIFIED Requirements

### Requirement: AI inline completion via copilot.lua
The configuration SHALL provide Copilot ghost-text suggestions through zbirenbaum/copilot.lua (the old-config engine) backed by the mason-installed copilot-language-server binary, with the old-config keys: `<C-t>` accepts the current suggestion line, `<C-w>` accepts the next word, `<M-l>` accepts the whole suggestion, `<M-]>`/`<M-[>` cycle alternatives, and `<C-]>` dismisses. Accept keys SHALL act only on a visible suggestion (`trigger_on_accept = false`); `<C-w>` is a direct global map that is a harmless no-op without a suggestion (built-in insert delete-word is intentionally not preserved), while `<C-t>` passes through to its built-in behavior. Ghost text SHALL NOT linger after leaving insert mode, regardless of whether insert mode is exited with `<Esc>` or `<C-c>`.

#### Scenario: No-op without suggestion
- **WHEN** no ghost suggestion is visible and the user presses `<C-w>` in insert mode
- **THEN** nothing happens (no deletion, no mode change)

#### Scenario: Accept word then line
- **WHEN** a multi-line ghost suggestion is visible and the user presses `<C-w>` then `<C-t>`
- **THEN** first only the suggestion's next word is inserted, then the remainder of the current suggestion line

#### Scenario: Ghost text accept
- **WHEN** Copilot is signed in and the user pauses while typing code
- **THEN** a ghost-text suggestion renders and `<M-l>` inserts all of it

#### Scenario: Dismiss
- **WHEN** a ghost-text suggestion is visible and the user presses `<C-]>`
- **THEN** the suggestion disappears without inserting text

#### Scenario: No lingering ghost text on Ctrl-C
- **WHEN** a suggestion is visible and the user exits insert mode with `<C-c>`
- **THEN** the ghost text is cleared
