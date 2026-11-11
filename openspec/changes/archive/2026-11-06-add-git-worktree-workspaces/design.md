# Design

## Context

See `proposal.md` for motivation and scope.

The configuration uses native `vim.pack` and explicit plugin setup. Neogit already has worktree operations in the locked revision, `f8674ec894315c02449b61c9de9a116c5aafeb90`; Telescope supplies both ordinary pickers and `vim.ui.select`. No additional worktree plugin is needed.

Existing workspace persistence is split between auto-session and two cwd-keyed JSON sidecars:

- `config.workspace` stores buffers, bufferline pins, and DAP breakpoints, with a 500 ms mutation-time save.
- `plugins.auto-session` stores neo-tree expansion/open state with a separate debounce, and schedules explorer and pin restoration after session loads.
- scope.nvim saves per-tab buffer membership through session hooks.

These paths currently evaluate cwd when callbacks execute. Merely changing directory can therefore save outgoing state under the incoming workspace's key. Stopping a timer alone is insufficient if its callback has already been scheduled.

Neogit's stock worktree popup is also not the requested workflow: some creation actions ask for the path before the branch, and visiting changes the status buffer's checkout without saving/restoring the full editor workspace. Its post-create event occurs too late to protect outgoing state.

## Goals / Non-Goals

**Goals:**

- Have one managed transition path shared by leader mappings and the configured Neogit worktree entry point.
- Keep Git operation results, user input, and editor state changes explicitly ordered.
- Preserve existing session/sidecar formats and ordinary startup behavior.
- Make errors and partial Git success visible without overwriting recoverable workspace state.

**Non-Goals:**

- One worktree per tab, separate editor instances, or a general project manager.
- Automatically fetching, rebasing, pushing, copying `.env`/dependencies, or managing external processes.
- Moving/pruning worktrees, deleting branches, or deleting saved session files when removing a checkout.
- Bare-only repositories with no main checkout, or automatic migration of existing workspace state.
- Intercepting arbitrary `:cd`, external Git commands, or direct calls into upstream popup internals.

## Decisions

### 1. Reuse Neogit behind a small managed integration

Add `lua/plugins/worktrees.lua` as a focused integration module. It owns action selection, repository discovery, the branch/path creation flow, and the transition coordinator. Keep persistence internals in the modules that already own them rather than adding another state store or generic event framework.

Use Neogit's existing Git worktree operations for mutations. Bind Neogit's repository context to the captured source checkout immediately before each operation; its command builder uses `git.repo.worktree_root`, not an arbitrary caller-supplied cwd. Capture and verify results and refresh/rebind Neogit after successful operations. Keep this library-facing adapter small and cover it against the locked revision because these are internal Neogit APIs.

Read repository/ref metadata with argument-array Git commands, including `git worktree list --porcelain -z`. Do not rely on Neogit's current list helper, which omits detached worktrees, or parse human-formatted output by whitespace. Never construct shell command strings from paths or branch names.

Set up the module after Telescope and auto-session. Neogit configuration can register lazy callbacks without requiring an initialized transition coordinator during startup.

Alternatives rejected: another dedicated worktree dependency; replacing vendor functions; using post-change hooks to save the outgoing workspace; duplicating Neogit's whole Git UI.

### 2. Derive the default from Git's main checkout, not the current folder

Resolve the current checkout and main checkout using Git's registered worktree metadata on every action. The main checkout determines the suggested destination; the actual outgoing cwd determines which existing session must be saved.

For main checkout `/any/parent/my-repo`, default to:

```text
/any/parent/my-repo.worktrees/<local-branch-name>
```

This stays identical from the main checkout, one of its subdirectories, a linked checkout in `my-repo.worktrees`, or a manually placed checkout such as `/tmp/review`. No directory named `Github` has special treatment, and the implementation does not strip or append suffixes to the current cwd to guess the main checkout.

Preserve `/` in branch names. Normalize absolute paths and use filesystem identity for equality/protection checks, including symlink aliases, without globally changing existing session-key conventions. If a usable main checkout cannot be established, report the unsupported/unavailable repository context rather than guessing.

### 3. Collect branch and editable destination before mutating Git

Use the existing Telescope-backed selection provider for local branches, remote-tracking branches, and an explicit "Create new branch" action. Validate a new name before displaying the destination prompt. Preserve ref identity: a local branch containing `/` is not automatically a remote ref.

For a remote selection, strip only its known remote prefix when deriving the local name and destination. Reuse a matching existing local branch; otherwise create a local tracking branch from the selected remote ref. New explicitly named branches start from the invoking checkout's `HEAD`. Never fetch or rebase to prepare a selection; work with available local refs and explain missing ones.

Display an actual editable absolute default in the path input, not just placeholder text. Expand an edited home-relative path; resolve a relative override against the main checkout, consistently from all worktrees. Reject empty input and any existing destination, including a symlink. Cancellation before confirmation has no filesystem/Git side effects.

After initial transition preflight, create using a single checked worktree-add operation, with branch-creation/tracking flags when needed. Do not pre-create a branch separately. Verify the target is registered to the same repository before offering it to the transition coordinator. Creation itself does not change editor cwd.

Run transition preflight again after an asynchronous Git operation, since the user may have edited buffers in the meantime. If checkout creation succeeded but the subsequent switch is cancelled or fails, retain the new checkout and clearly report its location. Do not delete it or its branch as an automatic rollback.

### 4. Treat a workspace switch as a guarded transition

Serialize managed actions and capture their repository context. Reject a second action while one is in flight; selecting the current checkout is a no-op.

```text
Select and validate target
        |
Preflight: modified buffers and live resources
        |
Flush outgoing sidecars; pause/invalidate callbacks
        |
Save outgoing session, including scope state
        |
Clear outgoing editor state and change global cwd
        |
Restore target session + sidecars, or initialize cleanly
        |
Finish target callbacks; resume persistence
```

For modified buffers, including hidden buffers and other tabs, offer "Save all and switch" or "Cancel"; cancellation is the safe default. Save failures and unnamed modified buffers that cannot be written abort the transition. Uncommitted changes already on disk are allowed: separate checkouts are the point of worktrees.

Initially refuse switching while live Neovim terminal jobs would be destroyed or any DAP session is active. Tell the user which resources must be stopped/closed explicitly. Do not silently terminate, restart, or retarget terminal, debugger, or AI processes. External tmux/process sessions remain untouched and keep their original working directory.

Provide explicit pause/flush/resume support in the persistence-owning modules. Snapshot buffers, pins, breakpoints, and neo-tree before session saving can close plugin windows. Abort before directory changes or buffer teardown if saving fails. Managed switching is an explicit save even when exit autosave is toggled off; do not change the user's autosave preference.

Reset outgoing buffers/tabs, pin globals and groups, scope state, breakpoint registrations, and explorer runtime state while persistence is paused. Use existing plugin APIs; do not remap old absolute filenames into the destination by basename.

Restore the destination's session and existing post-restore behavior with the destination identity captured. If no session exists, initialize one clean editor buffer rooted at the target, reconcile any existing sidecar state, and keep neo-tree closed unless target state says otherwise. Absence of a session is not a restore error; an existing session that fails to load is.

Preserve rollback information. If restoration fails after cwd changed, keep writes paused, report the error, and attempt to return to the saved outgoing workspace. If recovery also fails, disable automatic writes to avoid damaging either saved workspace and report the current cwd and recoverable source state. Never disguise a broken restore as a successful empty workspace.

### 5. Make persistence destination-aware and invalidate stale work

Both persistence owners capture the workspace identity and a generation token for scheduled callbacks. Advancing the generation invalidates timers already queued on Neovim's event loop. Pausing suppresses change events caused by buffer cleanup, breakpoint clearing, and explorer teardown.

Guard deferred pin restoration, explorer restoration, and session-load ghost cleanup with the same transition identity. An older callback must not read the new cwd and act on a different workspace. Resume writes only when the active restoration sequence has completed, not after an arbitrary fixed delay.

Keep missing sidecars distinct from existing snapshots with empty buffers/pins/breakpoints/folder lists. Empty saved state is authoritative and must clear stale runtime/session state; missing state must not erase otherwise valid restored session state. Do not change existing on-disk paths or add a parallel worktree-specific persistence format.

### 6. Expose one managed interface and conservative deletion

Use described mappings under which-key group `<leader>gw`:

| Mapping | Action |
| --- | --- |
| `<leader>gww` | Select and switch worktree |
| `<leader>gwc` | Create worktree and switch workspace |
| `<leader>gwd` | Select and remove a non-current linked worktree |

Replace Neogit's configured status-buffer `w` mapping with a function-valued mapping that opens the same managed action menu. This is supported by the locked Neogit configuration and avoids patching vendor popup actions. Restore the underlying editing focus before snapshotting a workspace opened from the floating Git UI. Other Neogit mappings keep their meaning.

The raw upstream `:Neogit worktree` popup remains an advanced Git-only interface, not the configured full-workspace entry point; document this boundary rather than claiming to intercept all upstream actions.

Deletion requires confirmation showing the exact absolute path and branch. Revalidate immediately before mutation, protect the main checkout/current checkout and locked worktrees, and reject modified or untracked content, including ignored local files. Do not expose forced deletion or automatically unlock/prune. Successful removal refreshes the list without changing the active workspace and leaves saved editor state available.

## Risks / Trade-offs

- [Neogit internal API changes] -> Isolate the adapter, use the existing lockfile, and exercise it in regression checks; no broad plugin update is needed for this feature.
- [State leaks through queued callbacks or empty snapshots] -> Explicit identity/generation guards, paused teardown, and tests that wait past the existing debounce/defer intervals.
- [Git succeeds but editor switching fails] -> Preserve and report the created checkout; recover the outgoing editor session independently.
- [Live-job refusal is conservative] -> Prefer a clear refusal over silent termination in the initial version. Process migration is outside scope.
- [Filesystem or Git state changes after selection] -> Revalidate target identity, branch availability, locks, and destination immediately before the relevant operation; report Git's actual failure.
- [A user invokes the raw upstream popup directly] -> Document the managed keymaps and Neogit `w` menu as the supported workspace flow; do not install invasive global hooks.

## Migration Plan

Implement and test in isolated temporary repositories and editor state directories first. Add the integration and persistence APIs without installing plugins or rewriting existing sessions, then wire the leader group and Neogit menu. Update README examples with arbitrary parent directories and creation from an existing linked checkout.

Rollback removes the integration setup/menu mapping and transition-specific changes. Existing cwd-keyed sessions and sidecars remain readable, and created Git worktrees remain ordinary Git worktrees usable independently of Neovim.
