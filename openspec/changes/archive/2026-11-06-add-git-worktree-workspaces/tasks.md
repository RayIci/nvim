# Tasks

## 1. Repository discovery and Neogit adapter

- [x] 1.1 Establish a focused headless Lua regression runner using built-in assertions, disposable Git fixtures, and isolated editor state; verify it runs without loading the user's full init, installing plugins, or changing real repositories.
- [x] 1.2 Add repository discovery and NUL-delimited registered-worktree parsing in `lua/plugins/worktrees.lua`; verify main/linked/subdirectory contexts, external linked locations, detached checkouts, spaces, filesystem aliases, and unsupported contexts in the regression runner.
- [x] 1.3 Implement `<main-checkout>.worktrees/<local-branch-name>` destination derivation and normalized path validation; verify arbitrary parent folders, branch slashes, relative/home overrides, and existing/dangling-symlink destinations without creating files during prompting.
- [x] 1.4 Add the narrow Neogit mutation adapter with explicit repository-context binding, checked results, and refresh/rebind behavior; verify against the locked Neogit revision and ensure creation from a linked checkout uses its HEAD rather than stale main-checkout context.
- [x] 1.5 Document the destination rule and normal-checkout support boundary in the README; verify its examples match the path-resolution fixtures, including creation from another worktree.

## 2. Branch selection, creation, and removal

- [x] 2.1 Add the Telescope-backed local/remote branch selector and explicit new-branch action, followed by an editable absolute path prompt; verify prompt defaults, selected-versus-created branch identity, validation, overrides, and cancellation with stubbed UI callbacks.
- [x] 2.2 Implement checked local-only creation for existing branches, new branches at the invoking HEAD, and remote selections with/without an existing local counterpart; verify real temporary-repository outcomes, tracking configuration, checked-out-branch refusal, and absence of implicit fetch/rebase/push operations.
- [x] 2.3 Verify successful creation against the registered checkout list before requesting a workspace switch, and report both Git failures and created-but-not-opened outcomes; verify failed creation never changes editor cwd and cancelled subsequent switching preserves/reports the new checkout.
- [x] 2.4 Implement confirmed deletion with immediate main/current/alias/lock/content revalidation and no forced removal; verify clean removal, staged/modified/untracked/ignored-file refusal, cancellation, and preservation of branches and saved editor state.
- [x] 2.5 Document local-only creation, tracking behavior, deletion safeguards, and separate `.env`/dependency setup in the README; verify the documented behavior against this group's Git fixtures.

## 3. Transition-aware persistence

- [x] 3.1 Add explicit outgoing-state flush, pause/resume, captured workspace identity, and generation invalidation to `lua/config/workspace.lua`; verify pending and already-scheduled saves never write source state under the target's key.
- [x] 3.2 Add corresponding neo-tree snapshot lifecycle handling and destination/generation guards to `lua/plugins/auto-session.lua`, including deferred pin/explorer and session-load cleanup callbacks; verify stale callbacks cannot alter a later workspace and active restoration has an explicit completion path.
- [x] 3.3 Distinguish missing sidecars from authoritative empty snapshots during reconciliation/restoration; verify empty pins/buffers/breakpoints/expansions clear stale state while absent sidecars preserve valid session-restored state.
- [x] 3.4 Cover persistence with delayed-callback regression cases that run past existing debounce/defer intervals, and update README persistence notes; verify ordinary mutation-time saves, restart reconciliation, and existing on-disk locations remain intact.

## 4. Guarded whole-workspace transitions

- [x] 4.1 Implement serialized action handling and preflight across hidden/all-tab modified buffers, with safe-default save-or-cancel behavior and live terminal/DAP checks; verify cancelled/failed writes, modified unnamed buffers, live jobs, active debug sessions, no-op current selection, and repeated action requests leave source state safe.
- [x] 4.2 Integrate outgoing sidecar flush and explicit auto-session save before teardown, preserving the user's exit-autosave preference; verify save failures abort before cwd/buffer changes and unsaved edits introduced during asynchronous creation trigger a second preflight.
- [x] 4.3 Implement full source buffer/tab/pin/scope/breakpoint/explorer cleanup and target restoration through existing plugin APIs; verify A-to-B-to-A restores distinct layouts, per-tab memberships, pins, breakpoints, and explorer state without basename-based file substitution or source buffer leakage.
- [x] 4.4 Implement first-visit and sidecar-only restoration paths and resume persistence only after active restoration completes; verify a new checkout starts with one clean buffer and closed explorer, while sidecar-only target state is recovered.
- [x] 4.5 Implement explicit restore-failure reporting and source-session recovery without overwriting target state; verify corrupt target sessions, rollback failure, paused/disabled writes on unrecoverable failure, and visible recovery information.
- [x] 4.6 Document switching guards, explicit-save behavior, first visits, recovery, and unchanged external-process working directories in the README; verify examples and resource-limit descriptions match the transition regression cases.

## 5. Managed entry points and integration checks

- [x] 5.1 Wire setup after Telescope/auto-session, add described `<leader>gww`/`gwc`/`gwd` mappings and the which-key group, and route Neogit's status `w` through the shared managed action menu using supported function-valued mappings; verify both entry paths invoke the same flow and floating Git menus do not replace saved editing layouts.
- [x] 5.2 Update the README binding table and distinguish the managed workflow from the advanced raw `:Neogit worktree` popup; verify all documented mappings exist and unrelated Git/session bindings remain unchanged.
- [x] 5.3 Run the targeted headless suite and repository-standard formatting/type checks for touched Lua files, using existing tooling only; verify all worktree/path/state/failure scenarios pass without broad plugin or lockfile changes.
- [x] 5.4 Exercise the actual configured plugins in a disposable main checkout and linked checkout: create with the default and an override, create again from a linked checkout, switch both directions, remove a clean inactive worktree, and test both leader and Neogit-menu entry points; verify exact destinations and no cross-workspace state leakage.
- [x] 5.5 Confirm existing plain-startup restore, explicit-file startup, manual session mappings, per-tab scoping, and restart persistence still work with the integration enabled; verify the same state files remain usable when the new worktree entry points are disabled.
