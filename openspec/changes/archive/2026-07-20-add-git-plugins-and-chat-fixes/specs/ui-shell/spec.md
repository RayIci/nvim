# ui-shell Delta

## ADDED Requirements

### Requirement: Per-tab buffer scoping via scope.nvim
The configuration SHALL scope listed buffers per tabpage via scope.nvim, so the bufferline shows only buffers opened in the current tab. Scope state SHALL persist across sessions: auto-session SHALL run `ScopeSaveState` before saving and `ScopeLoadState` before restoring a session, and `sessionoptions` SHALL retain `tabpages` and `globals`.

#### Scenario: Buffers isolated per tab
- **WHEN** the user opens file A in tab 1, creates a new tab, and opens file B
- **THEN** tab 2's bufferline shows only B, and switching back to tab 1 shows only A

#### Scenario: Scope state survives a session round-trip
- **WHEN** the user exits Neovim with two tabs holding different buffer sets and restarts into the restored session
- **THEN** each restored tab shows only its own buffers
