# core-keymaps Delta

## ADDED Requirements

### Requirement: Pin-aware bulk buffer closing
The configuration SHALL provide bulk buffer-closing keymaps that respect bufferline pins and unsaved changes: `<leader>xa` SHALL delete all listed buffers that are neither pinned nor modified (creating a scratch buffer first so the editor survives, then focusing a remaining buffer if any), and `<leader>xA` SHALL delete all listed buffers except the current one, pinned ones, and modified ones.

#### Scenario: Close all keeps pinned and unsaved
- **WHEN** five buffers are open — one pinned, one modified — and the user presses `<leader>xa`
- **THEN** the three plain buffers are deleted while the pinned and modified buffers stay open

#### Scenario: Close others keeps current
- **WHEN** several buffers are open and the user presses `<leader>xA`
- **THEN** only the current buffer plus any pinned or modified buffers remain

### Requirement: Ctrl-C leaves insert mode as Escape
Insert-mode `<C-c>` SHALL behave as `<Esc>`, firing `InsertLeave` so mode-exit hooks (inline-suggestion cleanup, deferred diagnostics refresh) run.

#### Scenario: InsertLeave fires on Ctrl-C
- **WHEN** the user exits insert mode with `<C-c>` while a Copilot ghost-text suggestion is visible
- **THEN** InsertLeave autocmds fire and the ghost text is cleared, same as exiting with `<Esc>`

### Requirement: Save without formatting
`<C-a>` in normal and insert mode SHALL save the current buffer while bypassing format-on-save for that single write only; subsequent plain saves format again. Normal-mode number increment is shadowed (visual-mode `<C-a>` increment is unaffected).

#### Scenario: One-shot bypass
- **WHEN** format-on-save is enabled and the user saves a badly formatted buffer with `<C-a>`, then saves again with `<C-s>`
- **THEN** the first write leaves the content unformatted and the second write formats it

### Requirement: Shift+Enter stays in insert mode
Insert-mode `<S-CR>` SHALL insert a newline and remain in insert mode, identical to plain `<CR>` (modern terminals send Shift+Enter as a distinct key that would otherwise leave insert mode).

#### Scenario: Newline via Shift+Enter
- **WHEN** the user presses Shift+Enter while typing
- **THEN** the cursor moves to a new line and insert mode continues

### Requirement: jk and jj escape insert mode without lag
Typing `jk` or `jj` in insert mode SHALL return to normal mode via better-escape.nvim, with the first `j` rendered instantly (no pending-map delay) and removed when the sequence completes. The sequences SHALL apply to insert mode only — never terminal or cmdline mode — so interactive TUIs (lazygit) and terminal j/k navigation are unaffected.

#### Scenario: Escape via jk
- **WHEN** the user types text and then `jk` quickly in insert mode
- **THEN** the editor is in normal mode and the buffer contains only the typed text, with no leftover `j`

#### Scenario: Terminals untouched
- **WHEN** the user types `jj` or `jk` rapidly inside a lazygit or toggleterm terminal
- **THEN** the keys reach the terminal program unchanged
