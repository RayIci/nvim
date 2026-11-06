# Design

## Context

- **How plugins are wired (from `refactor-config-and-extract-plugins`):**
  - Each `lua/plugins/<name>.lua` declares `M.spec` and `M.setup()` and is listed in `lua/plugins/init.lua`.
  - `config/pack.lua` installs every spec in one `vim.pack.add`.
  - `tests/plugin-modules.lua` requires each module with no plugins on `runtimepath`, so a module may only require its plugin inside functions.
- **How diffbandit loads:**
  - Its `plugin/diffbandit.lua` defines user commands and loads `diffbandit` on first use.
  - `require("diffbandit").setup(opts)` sets the options.
  - The public Lua API includes `close()` (the current tab's view and/or commit panel) and `is_running({ tab = t, panel = true })`.
  - A commit panel's message buffer has `buftype=acwrite` with a `BufWriteCmd` that commits the staged changes. Closing a panel saves an unfinished message as a per-repository draft and deletes the panel's buffers.
- **How a switch runs, in git-worktree.nvim's `switch_to`:**
  1. `preflight`, made of the participants' `check` hooks, then the live-terminal check, then the unsaved-buffer prompt, where "Save all and switch" runs `:write` on every modified buffer.
  2. `pause`, then `flush`, then saving the outgoing session through auto-session (which runs `pre_save_cmds`).
  3. `reset`, then the teardown.

  Participants run in registration order. `setup()` registers the integrations first (`dap`'s `check` refuses during a debug session). `lua/plugins/git-worktree.lua` then registers the workspace participant.
- **How the exit save runs:** auto-session saves on `VimLeavePre`, and `pre_save_cmds` is `{ workspace.session.pre_save }`. The same hook list runs for a manual `<leader>qs` save and for the save inside a switch.

## Goals / Non-Goals

**Goals:**
- Try diffbandit as a second diff viewer without touching any existing git plugin.
- diffbandit never leaves windows or buffers in a saved session, and is never written by a worktree switch.
- If diffbandit was never opened in this Neovim, the config does not load it.

**Non-Goals:**
- A diffview replacement path, or a shared "close all diff viewers" helper for diffview (it can reuse the same participant later).
- The `bin/diffbandit` launcher and git difftool/mergetool setup.
- Kitty-graphics ribbons. Windows Terminal lacks the protocol, and `connector_renderer = "auto"` already falls back to drawing with Unicode cells.

## Decisions

### One host module owns everything diffbandit-specific

`lua/plugins/diffbandit.lua` holds:
- `M.spec`.
- `M.setup()`: the options and the `<leader>gx` keymaps.
- `M.close_all()`: closes every tab that holds a diffbandit view or panel.
- `M.participant`: `{ name = "diffbandit", check = M.close_all }`.
- `M.close_on_exit()`.

`close_all()` returns at once when `package.loaded.diffbandit` is nil, so diffbandit is never loaded only to find nothing open. Otherwise it walks `nvim_list_tabpages()`: for each tab where `is_running({ tab = t, panel = true })`, it makes that tab current and calls `close()`, then returns to the starting tab if it still exists.

The other modules only reference these functions:
- `git-worktree.lua` registers `require("plugins.diffbandit").participant` right after the workspace participant.
- `auto-session.lua` appends `close_on_exit` to `pre_save_cmds`.

That keeps the pattern already used for `config.workspace.participant`, and both modules load without diffbandit installed.

*Alternative:* register the participant from `diffbandit.lua`'s own setup through `pcall(require, "git-worktree")`. Rejected because it hides the list of participants. `git-worktree.lua` stays the single place that says what takes part in a switch.

### Close in `check`, not in `flush` or `reset`

`flush` and `reset` run after the unsaved-buffer prompt. A commit panel with a typed message is a modified `acwrite` buffer with a name. "Save all and switch" would then `:write` it, which commits whatever is staged. `check` is the only hook that runs before that prompt.

**Cost:** the views are closed even when the switch is later cancelled or refused, for example by a live terminal or the unsaved prompt. Nothing is lost: the right pane is the real file buffer and is untouched, the commit message is kept as a draft, and the view reopens with one key.

**Ordering:** registering after the integrations and the workspace participant means `dap`'s `check` refuses a switch during a debug session before anything is closed.

*Alternative:* a `check` that raises "close diffbandit first" while a view is open. Rejected in exploration as one more thing to dismiss before every switch.

### Exit-only session hook

`close_on_exit()` calls `close_all()` only when `vim.v.exiting ~= vim.NIL`, which is set by the time `VimLeavePre` runs. A manual `<leader>qs` save therefore leaves a view open. The worktree switch already closed views in `check`.

**Why exit-only is enough:** a manually saved session that captured a view is overwritten by the exit save, which always runs last. Only a crash could leave a session with a diffbandit tab, and it would then restore with empty panes. That is acceptable for a trial.

*Alternative:* close on every pre-save. Rejected because `<leader>qs` would close the view you are reviewing.

### Track `main` until a release has the close API, then `vim.version.range("0")`

The plan was first written against `main`'s README. The latest release, v0.3.0 (Nov 3), predates about 30 commits that this design needs:
- `close()` and `:DiffBanditClose` (Nov 4).
- Commit-panel drafts, and deleting the panel's buffers on close. In v0.3.0, closing a panel only hides it, which leaves a modified `acwrite` commit buffer behind that "Save all and switch" would write, and so commit.
- `q` closing every view, and `g?` help.

So the spec uses `version = "main"`. The lockfile pins the exact revision, and `vim.pack.update()` shows `main`'s new commits for confirmation. Once a release contains these features (expected v0.4.0), switch to `vim.version.range("0")`, the way `blink.cmp` uses `vim.version.range("1")`. That's a one-line change, listed under workflow follow-up.

*Alternatives:*
- Stay on v0.3.0 and close views through diffbandit's internal `state` module. Rejected because it relies on internals that are changing upstream, and the commit-message draft would be lost.
- Wait for v0.4.0. Rejected because it delays the trial by a release cycle (5 to 8 weeks so far).

### Keys

- **Group:** `<leader>gx`, which is unused. `b` would be the natural letter, but `<leader>gb` is blame.
- **Group entries:** commands where diffbandit has them (`DiffBanditGit`, `DiffBanditGit --staged`, `DiffBanditGitCurrent`, `DiffBanditCommitPanel`, `DiffBanditGitLog`, `DiffBanditGitMenu`, `DiffBanditClose`), and the Lua `git_compare_branches({})` for the branch picker.
- **In-view keys:** `-` replaces `<Space>` in four options: `actions.keys.toggle_stage`, `git.panel.keys.toggle_stage`, `git.panel.keys.toggle_amend` and `folder.keys.toggle_expand`.
  - `-` is fugitive's toggle-stage key and is unmapped in this config.
  - Being buffer-local, it shadows only the built-in `-` motion, inside these views.
  - Staging and amend share `-` because they live in different windows, which is the same arrangement as diffbandit's defaults.
- **Everything else** keeps diffbandit's defaults. `g?` lists them from the live mappings.
- **`u` stays.** On the editable right pane, diffbandit's `u` runs native undo for ordinary edits and undoes a hunk action only when that action was the last change. On read-only panes it undoes hunk actions.

## Risks / Trade-offs

- **Tracking `main` brings in unreleased changes.** Options or keys may be renamed between commits, and `main` moves fast (44 commits in 30 days).
  - Mitigation: nothing moves except through `vim.pack.update()`, which shows the incoming commits for confirmation. The lockfile is in git, so `git checkout nvim-pack-lock.json` rolls it back.
- **`close()` from the launcher quits Neovim.** `close()` runs `confirm qall` under `bin/diffbandit`.
  - Mitigation: the launcher is out of scope and not installed, and `close_all()` only runs on switch and exit.
- **commitsmith may not attach to diffbandit's commit-message window.** It needs `filetype=gitcommit`.
  - Mitigation: none in scope. Neogit's commit flow keeps commitsmith, and the README notes the gap.
- **Two diff viewers mean two sets of keys to learn.** That's intended for a trial: diffview stays on `<leader>gd`, diffbandit is on `<leader>gx`.

## Migration Plan

Additive. To roll back, drop the `add-diffbandit` commits, or remove the module and its line from `plugins/init.lua`, then run `vim.pack.del({ "diffbandit.nvim" })`. To adopt diffbandit instead of diffview later, write a separate change.
