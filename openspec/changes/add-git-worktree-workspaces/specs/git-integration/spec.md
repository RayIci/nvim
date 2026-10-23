# Spec Delta

## ADDED Requirements

### Requirement: Managed worktree actions
The configuration SHALL provide worktree switching on `<leader>gww`, creation on `<leader>gwc`, and deletion on `<leader>gwd`, with descriptions under a `<leader>gw` which-key group. Neogit's configured status-buffer `w` entry point SHALL expose the same managed actions. Existing unrelated Git bindings SHALL retain their behavior.

#### Scenario: Discover worktree actions
- **WHEN** the user opens the `<leader>gw` group
- **THEN** described switch, create, and delete actions are available

#### Scenario: Consistent status-menu actions
- **WHEN** the user presses `w` in the Neogit status buffer and selects creation or switching
- **THEN** the same destination prompts and workspace safeguards apply as through the corresponding leader mapping

#### Scenario: Include all registered checkouts
- **WHEN** the user opens the worktree selector in a repository with a main checkout, linked branches, and a detached linked checkout
- **THEN** the selector identifies the registered checkouts by path and branch or detached status, without omitting the detached checkout

#### Scenario: Preserve existing Git controls
- **WHEN** the user invokes an existing status, stage, blame, commit, push, diff, or GitHub binding
- **THEN** it retains its existing behavior

### Requirement: Main-checkout-based destination default
Creation SHALL prefill an absolute destination of `<main-checkout>.worktrees/<local-branch-name>`, derived from the repository's registered main checkout rather than the invoking cwd. No parent folder name SHALL receive special treatment. Slashes in branch names SHALL remain path separators.

#### Scenario: Arbitrary parent directory
- **WHEN** the main checkout is `/work/client/backend` and the selected branch is `fix-auth`
- **THEN** the suggested destination is `/work/client/backend.worktrees/fix-auth`

#### Scenario: Hierarchical branch name
- **WHEN** the main checkout is `/work/client/backend` and the selected branch is `feature/login`
- **THEN** the suggested destination is `/work/client/backend.worktrees/feature/login`, distinct from the destination for `feature-login`

#### Scenario: Creation from another worktree
- **WHEN** the user creates `feature-b` from `/work/client/backend.worktrees/feature-a`
- **THEN** the suggested destination is `/work/client/backend.worktrees/feature-b`, with no additional `.worktrees` suffix or nesting under `feature-a`

#### Scenario: Creation from an unrelated linked-checkout location
- **WHEN** the user invokes creation from `/tmp/review-backend` or a subdirectory within it, and Git registers its main checkout as `/work/client/backend`
- **THEN** the suggested destination still uses `/work/client/backend.worktrees/<local-branch-name>`

#### Scenario: Unavailable main checkout
- **WHEN** a valid main checkout cannot be established, including a bare-only repository
- **THEN** creation reports that context explicitly without guessing a destination or mutating the repository

### Requirement: Branch-aware creation
Creation SHALL support an existing local branch, an available remote-tracking branch, or an explicitly named new branch. Remote selections SHALL derive the local name by removing only the selected remote's prefix, reusing a matching local branch or creating a tracking branch when absent. An explicitly named new branch SHALL start at the invoking checkout's HEAD.

#### Scenario: Existing local branch
- **WHEN** the user selects an available local branch `feature/login`
- **THEN** the new checkout uses that branch and its full local name determines the default path

#### Scenario: Remote branch without a local counterpart
- **WHEN** the user selects `upstream/feature/login` and no local `feature/login` branch exists
- **THEN** creation uses a local `feature/login` tracking the selected remote ref and suggests `<main-checkout>.worktrees/feature/login`, without an `upstream` path prefix

#### Scenario: Remote branch with a local counterpart
- **WHEN** the user selects `origin/feature/login` and a local `feature/login` branch already exists
- **THEN** creation uses the existing local branch without resetting it to the remote ref

#### Scenario: Explicit new branch
- **WHEN** the user chooses to create `experiment/new-flow` from a linked checkout
- **THEN** the new branch starts at that linked checkout's HEAD and its name determines the prefilled destination

#### Scenario: Branch already checked out
- **WHEN** the chosen local branch is already checked out in another worktree
- **THEN** creation reports the conflict without forcing duplicate checkout or changing the active workspace

### Requirement: Editable destination confirmation
The destination prompt SHALL contain the actual editable default after branch selection. Absolute and home-relative overrides SHALL be accepted; relative overrides SHALL resolve against the main checkout. Empty or existing destinations SHALL be rejected without overwriting content. Cancelling branch or destination selection SHALL create no branch, directory, or worktree and SHALL leave the active workspace unchanged.

#### Scenario: Accept the prefilled path
- **WHEN** the user confirms the destination without editing its prefilled value
- **THEN** creation targets exactly the displayed absolute path

#### Scenario: Edit the destination
- **WHEN** the user replaces the default with a different valid absolute path
- **THEN** creation uses that path without moving or renaming the main checkout

#### Scenario: Relative override from a linked checkout
- **WHEN** the main checkout is `/work/client/backend` and the user enters `../review-checkout` while working in a linked checkout
- **THEN** the destination resolves to `/work/client/review-checkout`

#### Scenario: Paths containing spaces
- **WHEN** a valid main checkout or destination contains spaces
- **THEN** the displayed path, created checkout, and subsequent workspace switch preserve the exact path

#### Scenario: Destination occupied or empty input
- **WHEN** the destination names an existing filesystem entry, including a symlink, or the submitted input is empty
- **THEN** creation reports the invalid destination and leaves existing content untouched

#### Scenario: Cancel before creation
- **WHEN** the user cancels either the branch selector or destination prompt
- **THEN** no branch or worktree is created, and cwd, buffers, and saved workspace state remain unchanged

### Requirement: Local-only worktree creation
Managed creation SHALL use available local Git refs and SHALL NOT implicitly fetch, rebase, push, rewrite an existing branch, copy untracked or ignored files, or install project dependencies. Fetching and project setup SHALL remain explicit user actions.

#### Scenario: Repository with a remote
- **WHEN** the user creates a worktree in a repository with an `origin` remote
- **THEN** creation performs no automatic network operation or rebase and does not alter existing branch histories

#### Scenario: Local project setup stays separate
- **WHEN** the source checkout contains an ignored `.env`, virtual environment, or dependency directory
- **THEN** creation does not copy or install it into the new checkout

### Requirement: Worktree operation failure reporting
Managed actions SHALL report invalid repository contexts and failed Git operations explicitly. Creation SHALL enter the workspace transition only after the target is verified as a registered checkout of the same repository. If creation succeeds but switching is cancelled or fails, the new checkout SHALL remain available and its path SHALL be reported without claiming the switch succeeded.

#### Scenario: Outside a repository
- **WHEN** the user invokes a worktree action outside a supported Git checkout
- **THEN** a visible explanation is shown without changing cwd, buffers, or creating a destination

#### Scenario: Git rejects creation
- **WHEN** Git rejects worktree creation
- **THEN** the failure is shown, no target workspace is opened, and any partial Git changes are not hidden or destructively cleaned up

#### Scenario: Checkout exists but transition is cancelled
- **WHEN** creation succeeds and a subsequent workspace preflight is cancelled
- **THEN** the current workspace remains active and the notification identifies the created checkout as available but not opened

### Requirement: Conservative linked-worktree deletion
Managed deletion SHALL require confirmation showing the exact checkout path and branch or detached status. It SHALL protect the main checkout, active checkout, and locked checkouts, and refuse modified, staged, or untracked content, including ignored local files. It SHALL NOT force removal, delete branches, or delete saved editor state.

#### Scenario: Remove a clean inactive checkout
- **WHEN** the user confirms removal of a clean, unlocked, inactive linked checkout
- **THEN** it is removed and the selector refreshes without switching the active workspace or deleting its retained editor state

#### Scenario: Protect the main or active checkout
- **WHEN** the requested removal identifies the main or active checkout, including through a filesystem alias
- **THEN** removal is refused and the checkout remains intact

#### Scenario: Protect local work and locks
- **WHEN** the selected checkout is locked or contains staged, modified, untracked, or ignored local files
- **THEN** removal is refused with a visible explanation and no force attempt is made

#### Scenario: Cancel deletion
- **WHEN** the user declines deletion confirmation
- **THEN** neither the checkout nor any saved editor state is removed
