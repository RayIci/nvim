# Spec Delta

## ADDED Requirements

### Requirement: Worktree plugin wiring
The configuration SHALL install the `git-worktree` plugin from its published repository and wire it: worktree switching on `<leader>gww`, creation on `<leader>gwc` and deletion on `<leader>gwd`, described under a `<leader>gw` which-key group, and Neogit's status-buffer `w` opening the plugin's action menu. The worktree behaviour itself is specified in the plugin's repository; this configuration owns only the wiring.

#### Scenario: Discover worktree actions
- **WHEN** the user opens the `<leader>gw` group
- **THEN** described switch, create, and delete actions are available

#### Scenario: Consistent status-menu actions
- **WHEN** the user presses `w` in the Neogit status buffer and selects creation or switching
- **THEN** the same destination prompts and workspace safeguards apply as through the corresponding leader mapping

#### Scenario: Preserve existing Git controls
- **WHEN** the user invokes an existing status, stage, blame, commit, push, diff, or GitHub binding
- **THEN** it retains its existing behavior

#### Scenario: Neogit not required for worktree actions
- **WHEN** a worktree is created or removed through the leader mappings while the Neogit status buffer has never been opened
- **THEN** the action completes, and the next time the status buffer opens it reflects the new set of worktrees

## MODIFIED Requirements

### Requirement: Commit-message plugin wiring
The configuration SHALL install the `commitsmith` commit-message plugin from its published repository and configure it, supplying its options and keymaps and providing the fallback callback that routes a commit-message prompt to Sidekick. The commit-message behaviour itself is specified in the plugin's repository; this configuration owns only the wiring. The Sidekick module SHALL NOT contain commit-message generation logic; it SHALL configure Sidekick only, taking the commit-message prompt it needs from the plugin's public API.

#### Scenario: Plugin wired with a Sidekick fallback
- **WHEN** the user invokes the generate keymap outside a `gitcommit` buffer
- **THEN** the configured fallback callback sends the commit-message prompt through Sidekick's CLI

#### Scenario: Sidekick module scope
- **WHEN** the Sidekick configuration module is loaded
- **THEN** it configures Sidekick and its CLI keymaps only, with no commit-generation code

#### Scenario: Settings carry over
- **WHEN** Neovim starts with the published plugin installed and an existing commitsmith settings file
- **THEN** the previously selected harness and models are still in effect

## REMOVED Requirements

### Requirement: Managed worktree actions
**Reason**: The worktree workflow moved to the `git-worktree` plugin; its keymap and entry-point parts are restated in "Worktree plugin wiring", and its checkout-listing scenario moves to the plugin.
**Migration**: See "Worktree plugin wiring" above; "Include all registered checkouts" is carried over into `openspec/specs/worktree-workspaces/spec.md` in RayIci/git-worktree.nvim.

### Requirement: Main-checkout-based destination default
**Reason**: Worktree destination rules are plugin behaviour, now in the `git-worktree` plugin.
**Migration**: Carried over unchanged into `openspec/specs/worktree-workspaces/spec.md` in RayIci/git-worktree.nvim.

### Requirement: Branch-aware creation
**Reason**: Worktree creation is plugin behaviour, now in the `git-worktree` plugin.
**Migration**: Carried over unchanged into `openspec/specs/worktree-workspaces/spec.md` in RayIci/git-worktree.nvim.

### Requirement: Editable destination confirmation
**Reason**: The destination prompt is plugin behaviour, now in the `git-worktree` plugin.
**Migration**: Carried over unchanged into `openspec/specs/worktree-workspaces/spec.md` in RayIci/git-worktree.nvim.

### Requirement: Local-only worktree creation
**Reason**: Worktree creation is plugin behaviour, now in the `git-worktree` plugin.
**Migration**: Carried over unchanged into `openspec/specs/worktree-workspaces/spec.md` in RayIci/git-worktree.nvim.

### Requirement: Worktree operation failure reporting
**Reason**: Failure reporting for worktree operations is plugin behaviour, now in the `git-worktree` plugin.
**Migration**: Carried over unchanged into `openspec/specs/worktree-workspaces/spec.md` in RayIci/git-worktree.nvim.

### Requirement: Conservative linked-worktree deletion
**Reason**: Worktree deletion is plugin behaviour, now in the `git-worktree` plugin.
**Migration**: Carried over unchanged into `openspec/specs/worktree-workspaces/spec.md` in RayIci/git-worktree.nvim.
