# Spec Delta

## ADDED Requirements

### Requirement: Whole-workspace worktree switching
A managed worktree switch SHALL replace the whole workspace in the current Neovim instance. It SHALL save the outgoing session and workspace state before changing directory, then restore the destination's buffers, tabs, layout, pins, breakpoints, and explorer state. Listed buffers and per-tab membership from the outgoing workspace SHALL NOT leak into the destination.

#### Scenario: Switch between saved workspaces
- **WHEN** worktrees A and B have different open files, layouts, tab memberships, pins, breakpoints, and explorer expansion states, and the user switches from A to B
- **THEN** B's saved state is restored, A's editor state is no longer active, and switching back restores A's outgoing state

#### Scenario: Switch from any editing tab
- **WHEN** the source workspace has multiple tabs and hidden buffers
- **THEN** switching saves and replaces the entire workspace rather than changing only the active tab's directory or file

#### Scenario: Switch through the floating Git interface
- **WHEN** the user initiates switching from the configured Neogit worktree menu
- **THEN** the outgoing editing layout is saved without replacing it with the transient Git menu

#### Scenario: Select the active checkout
- **WHEN** the user selects the already active checkout
- **THEN** no session reset, directory change, or buffer teardown occurs

### Requirement: First-visit workspace initialization
When the destination has no saved session, a managed switch SHALL start without outgoing buffers, tabs, pins, or breakpoint registrations. Existing destination workspace state SHALL still be restored; when neither a session nor sidecar state exists, the workspace SHALL contain one clean editing buffer rooted at the destination, with the explorer closed.

#### Scenario: Brand-new worktree
- **WHEN** the user switches to a newly created worktree with no saved editor state
- **THEN** the target becomes cwd, one clean editing buffer is shown, and no old pins, tabs, breakpoints, or explorer expansions are inherited

#### Scenario: Sidecar state without a session
- **WHEN** a destination has persisted buffers, pins, breakpoints, or explorer state but no session file
- **THEN** applicable destination state is restored without importing the source workspace's state

### Requirement: Unsaved-edit transition guard
Before leaving a workspace, managed creation/switching SHALL detect modified buffers across all tabs and hidden buffers and offer "Save all and switch" or "Cancel", defaulting safely to cancellation. Failed writes and modified unnamed buffers that cannot be saved SHALL prevent teardown. Saved but uncommitted Git changes SHALL NOT by themselves prevent switching.

#### Scenario: Cancel with unsaved edits
- **WHEN** any source buffer is modified and the user cancels the transition
- **THEN** cwd and all source buffers remain active with their edits intact

#### Scenario: Save all before switching
- **WHEN** modified file-backed buffers exist and the user chooses to save all
- **THEN** every modified buffer is written successfully before outgoing state is discarded or cwd changes

#### Scenario: Hidden or unwritable buffer
- **WHEN** a hidden buffer or buffer in another tab cannot be written, or a modified unnamed buffer cannot be saved
- **THEN** switching is aborted with a visible explanation, and no unsaved buffer is discarded

#### Scenario: Saved Git changes remain in their checkout
- **WHEN** the source checkout contains saved, uncommitted changes but no unsaved editor buffers
- **THEN** switching is allowed and those changes remain in the source checkout

#### Scenario: Edits during creation
- **WHEN** the user modifies a source buffer while a worktree creation operation is in progress
- **THEN** the modified-buffer guard is applied again before the subsequent workspace teardown

### Requirement: Live-resource transition guard
A managed transition SHALL refuse to discard live Neovim terminal jobs or proceed while a debugging session is active. It SHALL identify the blocking resources without stopping them automatically. External terminal, tmux, server, and AI processes SHALL NOT be relocated or terminated by a workspace switch.

#### Scenario: Live terminal buffer
- **WHEN** a running terminal job would be discarded by the workspace reset
- **THEN** switching is refused with an explanation, and the job remains running in its original workspace

#### Scenario: Active debugger
- **WHEN** any debugging session is active
- **THEN** switching is refused without terminating or retargeting the debug session

#### Scenario: External process remains independent
- **WHEN** a successful switch occurs while an external process exists outside Neovim
- **THEN** the integration does not terminate it or claim its working directory has changed

### Requirement: Workspace persistence isolation
Managed transitions SHALL flush outgoing state under its original workspace identity before teardown and prevent transitional or stale callbacks from overwriting either workspace's saved state. Deferred restoration SHALL affect only the workspace for which it was scheduled. Existing empty snapshots SHALL be authoritative and distinct from missing snapshots.

#### Scenario: Save pending at switch time
- **WHEN** a source workspace save is pending when the user switches
- **THEN** the latest source state is saved under the source identity and the pending callback never writes it under the target identity

#### Scenario: Old restore callback fires late
- **WHEN** a pin, explorer, or session-load restoration callback from a previous workspace becomes ready after another workspace is active
- **THEN** it does not modify the active workspace or overwrite either workspace's stored state

#### Scenario: Empty state clears stale state
- **WHEN** the destination has an existing saved snapshot with empty buffers, pins, breakpoints, or explorer expansions
- **THEN** the corresponding stale runtime or session state is cleared rather than inherited from the source or an older destination session

#### Scenario: Missing sidecar preserves valid session state
- **WHEN** a destination session exists but a corresponding sidecar does not
- **THEN** valid state restored from that session is not erased merely because the sidecar is absent

#### Scenario: Rapid action requests
- **WHEN** another managed creation, switching, or deletion action is requested before the active action finishes
- **THEN** it is refused with a visible busy explanation rather than interleaving transitions

### Requirement: Recoverable workspace transition failures
A managed switch SHALL abort without changing cwd or discarding source buffers when saving outgoing state fails. A destination restore failure SHALL be reported distinctly from missing state, and recovery to the saved source workspace SHALL be attempted without overwriting destination state. If recovery fails, automatic writes SHALL stop and the user SHALL be told what remains recoverable.

#### Scenario: Outgoing save fails
- **WHEN** the session or sidecar save fails before teardown
- **THEN** switching is aborted, the source cwd and buffers remain active, and the error is shown

#### Scenario: Existing target session is broken
- **WHEN** the destination has a session file that fails to restore
- **THEN** the integration reports failure, does not replace the saved destination with an empty success-shaped session, and attempts to recover the saved source workspace

#### Scenario: Recovery also fails
- **WHEN** restoring both the destination and saved source fails
- **THEN** automatic writes are stopped and an error identifies the current directory and recoverable source state instead of announcing successful switching

### Requirement: Preserve ordinary session behavior
Outside managed transitions, existing startup restore, explicit-file startup, manual session mappings, per-tab scoping, and mutation-time persistence SHALL retain their behavior and storage locations. A managed switch SHALL explicitly save its outgoing workspace even when exit autosave is off, without changing that preference.

#### Scenario: Existing startup round-trip
- **WHEN** the user quits and reopens a checkout with no file arguments
- **THEN** its existing automatic session and workspace restoration continue to work

#### Scenario: Explicit file startup stays explicit
- **WHEN** the user starts Neovim with a file argument
- **THEN** the requested file opens without introducing automatic worktree switching or session restoration

#### Scenario: Exit autosave disabled
- **WHEN** the user has disabled exit autosave and performs a managed switch
- **THEN** the outgoing workspace is explicitly saved for the transition and the exit-autosave preference remains disabled

#### Scenario: Restart persistence remains intact
- **WHEN** buffers, pins, explorer state, or breakpoints change outside a managed transition and Neovim restarts without normal exit hooks
- **THEN** the existing mutation-time persistence continues to preserve the latest saved workspace state
