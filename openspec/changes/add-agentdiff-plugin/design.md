# Design

## Context

See proposal.md for motivation; the behaviour contract is in `specs/agent-change-review/spec.md`.

Current state that shapes the approach:

- Agents run in a separate tmux pane (99% of the time) and write files directly. Neovim learns about it only via `checktime`, which `lua/config/autocmds.lua` already runs on `FocusGained`/`TermLeave`/`BufEnter`/`CursorHold`. tmux has `focus-events on`, so pane switches reach Neovim. Home is on ext4.
- VS Code can snapshot a file right before the agent's first write because the agent writes *through* the editor. We cannot intercept writes, so a baseline must exist before the agent writes.
- Both Claude Code and Copilot CLI support an IDE lock-file protocol (`~/.claude/ide`, `~/.copilot/ide`). It's out of scope here (non-goal below) but explains why no hooks are needed for this change.
- Precedent: commitsmith lives in `lua/commitsmith/`, is relocatable, owns no host keymaps, and is wired by `lua/plugins/commitsmith.lua`. Commit `272d091` established stripping inherited `GIT_*` variables before running git subprocesses.
- There is no test infrastructure in the repository.

## Goals / Non-Goals

**Goals:**
- One attribution algorithm that covers agent writes, Neovim writes, claimed tool writes, unsaved buffers and git operations.
- No dependency besides Neovim and `git`; no configuration of any agent.
- Correct under multiple Neovim instances on the same project and across restarts.
- Fully testable headless, without a real agent.

**Non-Goals:**
- Pre-apply proposal diffs (approve before the agent writes) through the IDE protocols. That's a possible follow-up change on top of this one.
- Grouping changes per agent turn, checkpoints and restore points. These would need harness hooks.
- Multi-root workspaces: one project root per Neovim instance.
- Perfect attribution of non-Neovim, non-agent writers (a build script in another pane). See Risks.

## Decisions

### D1. Attribution by writer, not by harness integration
Every disk change is classified by *who wrote it*: Neovim (or something Neovim claims) is the user; anything else is the agent.
- *Alternatives:* harness hooks (per-harness config, unavailable or uncontrollable on a work machine); the IDE MCP protocol (per-harness, undocumented for Copilot, and it's a proposal flow, not review). Both were rejected as the foundation; neither is needed for review.

### D2. Shadow git store per project
State lives in `stdpath("state")/agentdiff/<sha256(project_root)>/`, a bare git directory used with `GIT_WORK_TREE=<project_root>`. Every git subprocess runs with an environment stripped of inherited `GIT_*` variables (the 272d091 lesson), plus explicit `GIT_DIR`, `GIT_WORK_TREE` and `GIT_INDEX_FILE`.
- **Project root:** the git toplevel when inside a repository, else the cwd. `DirChanged` re-roots.
- **Two index files** in the store:
  - `baseline`: the agreed content (B);
  - `observed`: the last disk content the plugin has processed (O).
- **Pending changes** = B vs disk.
- **Unprocessed disk changes** = O vs disk. Both are computed with `git diff-files --name-status` against the respective index (stat-cache fast), plus `git ls-files --others --exclude-standard` for new files.
- **Snapshot:** `ls-files -o --exclude-standard` into an empty index, then `update-index --add --stdin`. *Found while implementing:* `git add -A` aborts outright on a nested git repository (common when an agent clones something into the project); `ls-files` lists such a repository as `dir/`, which is skipped.
- **Excludes:** git reads the project's `.gitignore` files from the worktree automatically. The store's `info/exclude` holds the plugin defaults (`.git/`, `node_modules/`, common build dirs) plus a copy of the project's own `.git/info/exclude`.
- *Alternatives:* in-memory snapshots (lost on restart, can't cover never-opened files); copying the tree (expensive, no dedup); refs inside the project's own repo (pollutes it, fails outside git repos).

### D3. One rule for every change: rebase user deltas onto the baseline
When disk content of a file differs from O, the change from O to disk has an author:
- **Agent:** O := disk. B is unchanged, so the change is now pending.
- **User** (Neovim write or claim): B := merge3(base = O, ours = B, theirs = disk), resolving overlapping regions to *ours*. Then O := disk.

Non-overlapping user edits land in B (never pending). User edits touching a pending region stay only in the current content, so they become part of that change (spec: "Edits inside a pending change"). Saving with pending changes keeps them pending (spec: "Saving never accepts agent changes"). Created files have an empty base side, and deletions an empty theirs side.

The same merge runs in memory for **display**: a buffer with unsaved edits is shown against B_display = merge3(O, B, buffer_lines), so unsaved typing never shows as pending.

merge3 is a small pure-Lua diff3 over `vim.text.diff(..., { result_type = "indices" })` hunks: apply non-overlapping hunks from both sides, take *ours* on overlap. Changes that only touch each other count as overlapping, matching git.
- *Alternatives:* `git merge-file --ours` (needs temp files per call; too slow for TextChanged); "baseline := disk on every Neovim write" (would silently keep agent changes on `:w`).

### D4. Claims
Neovim writes are claimed automatically: `BufWritePre` records the claim and `BufWritePost` processes it synchronously, before any poll result can be applied.
- **API:** `claim(paths)` writes claim entries `{ path, time, pid }` to `claims/` in the store, so claims are visible to every instance.
- **Shell commands:** `:!`/filter commands use a **time-window claim**. `CmdlineLeave` on a shell command records a start time, and `ShellCmdPost`/`ShellFilterPost` claim every change first observed in that window.
- **Lifetime:** a claim is consumed when the change it covers is processed, and expires after 10 s if nothing used it. *Found while implementing:* expiry alone let an agent edit to a file within 10 s of the user saving it pass as the user's.
- **Command modifiers:** shell commands are recognised after modifiers (`:silent !cmd`, `:keepalt r !cmd`, …).
- **Stale polls:** poll results carry a generation number, and results older than the latest claim for a path are discarded.

### D5. Detection loop
While Neovim is focused, a 1 s timer runs the two `diff-files` queries asynchronously (`vim.system`). It pauses on `FocusLost` and runs immediately on `FocusGained`, `BufEnter` and `VimEnter`.

A new unclaimed change must be seen again by a confirmation poll 300 ms later before it's attributed to the agent. This settle period lets another instance's `BufWritePre` claim reach the store. The worst case is about 1.3 s plus git time, within the spec's 2 s.

Each poll measures its own duration, and the interval backs off for very large trees (with a notice).
- *Alternative:* recursive `uv.fs_event` (not recursive on Linux; one watcher per directory doesn't scale). Polling `diff-files` is stat-only and simple.

### D6. Buffers
- **Unmodified loaded buffers:** reload normally (`FileChangedShell` → `v:fcs_choice = "reload"`).
- **Modified buffers hit by an agent write:** the plugin handles `FileChangedShell` itself (no W12 prompt). It runs merge3(O, buffer, disk):
  - If there's no overlap, the merged lines go into the buffer as one undo block with the cursor preserved, and the buffer stays modified.
  - If there's overlap, the buffer is left unchanged and the file is marked conflicted.
- **Conflict resolution:** "take agent" reloads the buffer (`:edit!`, recoverable with `u`). "Keep mine" runs Undo-file on disk only. "Compare" opens the side-by-side view of buffer vs disk.

### D7. Keep and Undo
- **Keep** (hunk, range, file, all) writes new B content: B with the selected hunks replaced by the current content, via `git hash-object -w --stdin` + `git update-index --index-info` on `baseline`. The file is not touched.
- **Undo** (hunk, range, file, all) edits the buffer, loading an unlisted hidden buffer for unopened files: it replaces the regions with B's lines as one undo block, then writes the buffer. That write is a user write, so D3 resolves the overlap to B, which is correct.
- **Undoing an Undo:** each Undo records `{ buf, undo seq_cur, hunks }`. If a later `TextChanged` finds the buffer's `undotree().seq_cur` back before a recorded Undo, the restored content is attributed to the agent (O is set to it and B is left alone). That makes the change pending again (spec: "Undo is undoable").
- **Created and deleted files:** undoing a created file deletes it and wipes its buffer; undoing a deleted file writes B's blob back. Both are claimed.
- **Keep all / Undo all** confirm through `vim.fn.confirm`.

### D8. Git-guard
Each poll also stats the project's `HEAD`, `ORIG_HEAD`, `logs/HEAD` and `logs/refs/stash` (in the git dir from `git rev-parse --absolute-git-dir`, so worktrees work). If one moved, every file with an unprocessed change whose disk content equals HEAD (or that is gone and absent from HEAD) is processed as a user change: `git ls-tree` + `git diff --name-only HEAD`, read-only with `GIT_OPTIONAL_LOCKS=0`. Other pending changes are left alone, so a commit (HEAD moves, worktree doesn't) changes nothing. Read-only access to the project repo is the only access it gets.

*Refined while implementing:* the trigger is HEAD/stash movement and the match is against HEAD, not the index. Matching the index would hide an agent edit the agent had already staged with `git add`. `git restore` of a file (HEAD unchanged) is therefore shown as a pending change.

### D9. Multiple instances
Every instance on a project uses the same store. Mutations of `baseline`/`observed` go through git's own `index.lock`, with retry and backoff. Claims are shared files (D4). An instance notices another instance's B/O updates when it stats the index files, then re-renders.

### D10. Rendering
Extmarks in a plugin namespace:
- **Removed lines:** `virt_lines` above the hunk (`AgentdiffDelete`).
- **Added lines:** a line highlight (`AgentdiffAdd`).
- **Hint:** right-aligned virtual text on the hunk's first line (`AgentdiffHint`), e.g. `agent 2/5 · <leader>rk keep · <leader>ru undo`. Keys come from the keymaps actually registered.
- **Conflicts:** `AgentdiffConflict`.
- **Default links:** `DiffDelete`, `DiffAdd`, `Comment`, `DiagnosticWarn`.

No signs are placed by default, so gitsigns keeps the sign column. Hunks are recomputed debounced (100 ms) on `TextChanged`/`TextChangedI` and on store updates.
- **Side-by-side:** a read-only scratch buffer holding B, shown in a vertical split with `:diffthis`.
- **Panel:** a left-side split listing files in navigation order, with status and `+N −M`.

### D11. Plugin layout and API
```
lua/agentdiff/
  init.lua      setup(opts), :Agentdiff command, public API
  config.lua    defaults + validation
  store.lua     shadow git dir, sanitized git runner, B/O index ops
  merge.lua     pure-Lua diff3 (merge3), hunk computation
  detect.lua    poll loop, settle, focus handling, git-guard
  claims.lua    claim journal, write claims, time-window claims
  review.lua    per-file state, attribution (D3), keep/undo (D7), undo-seq journal
  buffers.lua   FileChangedShell handling, unsaved merges, conflicts
  render.lua    extmarks, hint, highlight groups
  panel.lua     changed-files panel
  sidebyside.lua
```
- **Public API:** `setup`, `next`/`prev`, `next_file`/`prev_file`, `keep`/`undo` (with `{ scope = "hunk"|"file"|"all", range = {l1,l2} }`), `panel`, `toggle_view`, `toggle_overlay`, `resolve`, `claim`, `status`.
- **Events:** `User AgentdiffChanged`.
- **Optional keymaps:** a `keymaps` table in `setup()`; the default is none.

### D12. Host wiring

- **`lua/plugins/agentdiff.lua`:** passes the options and keymaps (spec: editing-experience). It registers the statusline widget through `require("plugins.lualine").register()` and claims oil actions on `User OilActionsPost` (the event's `data.actions` carries the paths).
- **grug-far:** grug-far emits no event after replacing, but has `hooks.on_before_edit_file(on_finish, file)`, called right before it rewrites each file (both the ripgrep and the ast-grep engines). `lua/plugins/grug-far.lua` passes a hook that claims `file.path` and calls `on_finish("success")`. That's more precise than a time-window claim, so none is needed.
- **oil:** claims on both `OilActionsPre` and `OilActionsPost`. `claim()` expands an existing directory to every file under it, so directory moves and deletes are covered.
- **Statusline:** the wiring also refreshes lualine on `User AgentdiffChanged`, so the summary appears immediately instead of on lualine's next timer tick.
- **Elsewhere:** the which-key group goes in `lua/plugins/whichkey.lua`, the colour module in `lua/vale/integrations/agentdiff.lua`, and setup sits after commitsmith in `lua/plugins/init.lua`.
- **`checktime` autocmd:** the existing one stays; agentdiff only takes over `FileChangedShell` for the buffers it manages.

### D13. Tests
- **Runner:** `nvim --headless -u NONE -l tests/agentdiff/run.lua` runs `tests/agentdiff/*_spec.lua`, with a tiny built-in `describe`/`it`/`assert` and no framework.
- **Isolation:** each test gets a temp project dir and a temp `XDG_STATE_HOME`.
- **Simulating the agent:** plain `io.open` writes, which are unclaimed external writes. `agentdiff._test.poll_now()` drives detection synchronously.
- **Coverage:** one test per spec scenario where it's mechanically checkable, plus merge3 unit tests.
- **After extraction:** the directory moves to `tests/` in the plugin repository unchanged.

### D14. Fixes from first use
- **Reviewable paths.** A path takes part in review only when it has no `.git` segment and `git check-ignore --no-index` (store excludes plus the worktree's `.gitignore` files) doesn't ignore it; results are cached per session and reset when a `.gitignore` is written. The check applies where a buffer becomes a project path (`rel_of_buf`, the write hooks) and in detection. Before this, Neovim's own write of `.git/COMMIT_EDITMSG` recorded the file, and git's later rewrite showed as an agent change. Stale entries are dropped from both indexes when a ready store starts.
- **Discards.** Git-guard only sees HEAD moving; a discard (`git restore`, `git checkout -- f`, lazygit's file or hunk discard) doesn't move HEAD. A candidate change is the user's when `merge3(O, disk, HEAD) == HEAD`: it only moves regions back to HEAD's content. HEAD is read with `git cat-file --batch` (read-only). An agent edit moves away from HEAD, so it's still shown, staged or not. Limitation: discarding unstaged changes while different changes are staged moves toward the *index*, not HEAD, and is still shown.
- **Windows are never closed.** Deleting a buffer closes the windows that show it; with neo-tree's `close_if_last_window`, closing the last file window can quit Neovim. `buffers.wipe()` first shows the alternate buffer (or a new empty one) in every window, then deletes the buffer.
- **Persistent toggle.** `<state_dir>/enabled` holds `on|off <epoch>`, global to all projects. The epoch changes each time review is turned on; each store keeps the epoch it was built in (`<store>/epoch`) and is rebuilt from disk when they differ. Without this, every edit made while review was off, the user's included, would appear as an agent change afterwards.

### D15. Neo-tree
- **The save "flash" is not agentdiff.** A watcher on the project directory, with the real config saving Lua, Python, Markdown and JSON files, saw the same events with agentdiff on and off: conform runs `markdownlint` (no stdin support) on a temporary `.conform.<random>.<name>` next to the file and deletes it; neo-tree shows dotfiles and watches with libuv, so the file flashes in. It's repo-dependent only because it needs a Markdown save in an expanded folder. agentdiff never reports it: it's gone before the settle period ends. The neo-tree config now never shows `.conform.*`.
- **Marks.** The plugin exposes `path_status(path)` ("file" / "dir" / nil), answered from per-signature sets of pending files and their ancestor directories, so a tree can call it for every line. The host copies neo-tree's default renderers, inserts an `agentdiff` component before `git_status` (directories: only while collapsed, like git status), sets them for the filesystem source only, and refreshes the filesystem source on `User AgentdiffChanged`. Copying the defaults at setup keeps the rest of neo-tree's layout in step with neo-tree updates.

## Risks / Trade-offs

- [A non-agent writer outside Neovim (a build script, another editor) is shown as an agent change] → `.gitignore` and default excludes cover build output; Keep-file and Keep-all make dismissal quick. Documented as the one place where behaviour is "nearly identical" to VS Code.
- [An agent writes during a `:!` command or a tool's claim window and is attributed to the user] → windows are short and time-boxed; accepted.
- [Polling cost in very large trees] → stat-only `diff-files`, pause while unfocused, adaptive interval with a notice.
- [Index lock contention between instances] → git's lock plus retry and backoff; operations are small.
- [The settle period makes detection about 1 s slower] → still within the 2 s requirement; prevents misattributing another instance's writes.
- [The undo-of-Undo heuristic misreads complex undo-tree navigation] → only `seq_cur` crossing a recorded Undo point is interpreted; other cases fall back to D3 (content counts as the user's).
- [VS Code's exact behaviour for edits inside a pending change is from memory] → task 1.1 verifies it in VS Code before implementation and updates the spec if it differs.
- [The first snapshot of a big project takes seconds] → runs in the background; review is inactive until it finishes (spec: non-blocking initial snapshot).

## Migration Plan

Additive: no existing behaviour changes. Rollback means removing `require("plugins.agentdiff").setup()` from `lua/plugins/init.lua`. The store directory under `stdpath("state")/agentdiff` can be deleted at any time and is rebuilt from the current disk state. Extraction to its own repository later means moving `lua/agentdiff/` and `tests/agentdiff/` and adding the repo to `vim.pack`, with no code changes (spec: self-contained plugin).

**Extraction (done in this change).** The plugin and its tests now live in their own repository, `~/Github/agentdiff.nvim` (`lua/agentdiff/`, `tests/`, `doc/agentdiff.txt`, `docs/`). It is published as `RayIci/agentdiff.nvim` and installed like every other plugin: `gh("RayIci/agentdiff.nvim")` in `lua/config/pack.lua`, pinned in `nvim-pack-lock.json`, updated with `vim.pack.update()`, help tags built by `vim.pack`. The configuration keeps only the host wiring: `lua/plugins/agentdiff.lua` (setup, keymaps, statusline, oil and grug-far claims, neo-tree component), `lua/vale/integrations/agentdiff.lua` and the which-key group. To try unpushed edits, start Neovim with `--cmd 'set rtp^=~/Github/agentdiff.nvim'`.

## Open Questions

- Exact default exclude list and default size limit for "oversized" files (start with 1 MiB).
- Panel placement (left split vs float); start with a left split.
