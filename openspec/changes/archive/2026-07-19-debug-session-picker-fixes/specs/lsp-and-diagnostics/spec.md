# lsp-and-diagnostics Delta

## MODIFIED Requirements

### Requirement: LSP keymaps on attach
The configuration SHALL define buffer-local keymaps in an `LspAttach` autocmd for: go-to-definition, references, hover, rename, and code action, each with a `desc` for which-key. Signature help SHALL NOT be mapped in insert mode on attach — it is owned by blink.cmp's completion signature window and its `<C-k>` toggle — leaving `<C-s>` free for saving. Additionally a `<leader>l` which-key group SHALL collect the LSP command tree (old-config layout on native/telescope equivalents): `la` code action, `lr` rename, `lk` signature help, `lo` symbol outline, diagnostics subgroup `ld*` (line float, buffer picker, workspace picker, loclist, quickfix), workspace-folder subgroup `lw*` (add/remove/list), call-hierarchy subgroup `lh*` (incoming/outgoing via telescope), `li` global inlay-hint toggle, and codelens subgroup `lc*` (run, refresh, toggle) — with code lenses auto-refreshing on `BufEnter`/`CursorHold`/`InsertLeave` for supporting servers while the global toggle is on (default on).

#### Scenario: Keymaps available after attach
- **WHEN** an LSP client attaches to a buffer
- **THEN** `grd`/`grr`/`K`/`grn`/`gra` (or the chosen equivalents) work in that buffer and the `<leader>l` tree appears in which-key

#### Scenario: Ctrl-S is not shadowed
- **WHEN** an LSP client attaches to a buffer and the user presses `<C-s>` in insert mode
- **THEN** the buffer is saved and no signature-help window opens

#### Scenario: Codelens lifecycle
- **WHEN** a server supporting code lenses attaches and the user toggles lenses off with `<leader>lct`
- **THEN** rendered lenses are cleared and no refresh runs until toggled back on

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
