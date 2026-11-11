# Spec Delta

## ADDED Requirements

### Requirement: Whole-workspace worktree switch
A managed worktree switch SHALL replace the whole workspace in the current Neovim instance. It SHALL save the outgoing session and workspace state before changing directory, then restore the destination's buffers, tabs, layout, pins, breakpoints, and explorer state. Listed buffers and per-tab membership from the outgoing workspace SHALL NOT leak into the destination.

#### Scenario: Switch between saved workspaces
- **WHEN** worktrees A and B have different open files, layouts, tab memberships, pins, breakpoints, and explorer expansion states, and the user switches from A to B
- **THEN** B's saved state is restored, A's editor state is no longer active, and switching back restores A's outgoing state

#### Scenario: Switch from any editing tab
- **WHEN** the source workspace has multiple tabs and hidden buffers
- **THEN** switching saves and replaces the entire workspace rather than changing only the active tab's directory or file

#### Scenario: Select the active checkout
- **WHEN** the user selects the already active checkout
- **THEN** no session reset, directory change, or buffer teardown occurs

## REMOVED Requirements

### Requirement: Whole-workspace worktree switching
**Reason**: One scenario covered switching from Neogit's floating menu, which no longer exists. The rest of the behaviour is restated unchanged as "Whole-workspace worktree switch".
**Migration**: Switch with `<leader>gww`.
