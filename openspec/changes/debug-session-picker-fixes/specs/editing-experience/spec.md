# editing-experience Delta

## MODIFIED Requirements

### Requirement: AI inline completion via native LSP
The configuration SHALL provide Copilot ghost-text suggestions through `vim.lsp.inline_completion` backed by copilot-language-server installed via mason, with old-config-style buffer-local insert keymaps: `<C-t>` accepts the first line of the suggestion, `<C-w>` accepts the first word (both implemented via the native `on_accept` hook trimming `insert_text`; snippet items fall back to full accept), `<M-l>` accepts the whole suggestion, `<M-]>`/`<M-[>` cycle alternatives, and `<C-]>` dismisses. Ghost text SHALL NOT linger after leaving insert mode, regardless of whether insert mode is exited with `<Esc>` or `<C-c>`. No copilot.lua/copilot.vim plugin SHALL be used.

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
