# Design

## Context

Today `lua/plugins/git-conflict.lua` sets up git-conflict.nvim with `<leader>gC` keys for ours/theirs/both/none/next/prev, plus quickfix and Trouble listing. git-conflict draws "(Current changes)"/"(Incoming changes)" labels from git's marker order. During a rebase that order is the reverse of the user's intent. diffview is installed and has a merge tool (3-way layouts, `conflict_choose("ours"|"theirs"|"base"|"all"|"none")`). The statusline supports registered widgets (`plugins.lualine.register`). The themes (vale) define `GitConflictCurrent`, `GitConflictIncoming`, `GitConflictAncestor` and their `*Label` variants.

## Goals / Non-Goals

**Goals:**
- One role model (yours/incoming) used by labels, keys, the resolve view, the conflict center and the 3-way view.
- Zero git processes and zero buffer scanning when no operation is in progress.

**Non-Goals:**
- Writing commit messages for merges (git's default message is used; lazygit or commitsmith can amend).
- Resolving binary or delete/modify conflicts. The center lists them and names the git command, but offers no line-level view.

## Decisions

- **Own module instead of git-conflict.** Fixing role labels needs control of label text and of which marker section each key keeps. git-conflict exposes neither. The parsing and highlighting it does are small (marker scan plus extmarks), so the module owns them. It reuses the `GitConflict*` highlight groups, so the theme needs no change.
- **Operation detection by filesystem, not by git commands** (`conflicts/state.lua`):
  - find the git dir from `vim.fs.root(0, ".git")`, following a `gitdir:` pointer file for linked worktrees;
  - `fs_stat` `MERGE_HEAD`, `rebase-merge/`, `rebase-apply/`, `CHERRY_PICK_HEAD` and `REVERT_HEAD`;
  - runs on VimEnter, FocusGained, DirChanged, TermLeave (lazygit and toggleterm) and after the module's own actions.

  Only when an operation is found does it run one batch of `vim.system` calls:
  - `git diff --name-only --diff-filter=U` for unmerged files;
  - `git log -1 --format=%h%x00%s` for each side's commit;
  - `git name-rev --name-only --refs=refs/heads/*` for branch names;
  - `rebase-merge/{head-name,onto,msgnum,end}` (or `rebase-apply/{next,last}`) for progress.

  A stash conflict has no state file. It is recognised by unmerged files whose markers read `Updated upstream`/`Stashed changes`.
- **Role mapping in one table.** Git's marker sections are *ours* (`<<<<<<<`) and *theirs* (`>>>>>>>`). For merge, cherry-pick, revert and stash: yours = ours, incoming = theirs. For rebase: yours = theirs, incoming = ours. Every caller asks `state.section(role)`, so no other code knows git's words. The explain panel prints the table row for the current operation.
- **Inline marking** (`conflicts/inline.lua`):
  - parse marker blocks, including diff3/zdiff3 `|||||||` ancestor sections, into `{ yours, base?, incoming, range }` in role terms;
  - draw `line_hl_group` extmarks and an end-of-line virtual-text label on each marker line;
  - re-parse on `TextChanged`/`InsertLeave` for attached buffers only;
  - attach on BufReadPost and BufEnter, only for files in the unmerged set;
  - detach when a buffer has no markers left. That moment triggers the "stage it" suggestion.
- **Resolve view as its own tab** (`conflicts/resolve.lua`), chosen over a float because three panes plus preview need the room. Layout: YOURS (top left), INCOMING (top right), RESULT (bottom); the latter shows the real buffer's lines around the conflict (5 lines of context each side) with the composed lines in place.
  - *Model:* an ordered list of kept entries `{ role, index }`. `o`/`t`/`b`/`B`/`x` replace the list. `<Space>` toggles an entry, appending it after the last kept line of the same role, or at the end. `J`/`K` swap with a neighbour.
  - *Preview:* re-rendered on every change.
  - *`e`:* makes the RESULT conflict region modifiable and switches to free text.
  - *Apply:* one `nvim_buf_set_lines` over the marker range, which is a single undo step. The resulting `changedtick` is recorded, and `u` undoes in the real buffer only if `changedtick` still matches; otherwise it explains that the file changed since.

  The pane winbars show the role labels, including branch and commit.
- **Conflict center** (`conflicts/center.lua`): a `snacks.win` float rendering the header, the side legend and the file list (with counts from parsing, or from the unmerged list for unopened files). Keys: `<CR>` resolve view on the file's first conflict, `m` 3-way, `s` stage, `c` continue, `S` skip (rebase only), `A` abort, `r` refresh, `?` explain, `q` close.
- **3-way view via diffview** (`<leader>gCm`):
  - `view.merge_tool.layout = "diff3_mixed"` puts yours/incoming on top and the result below;
  - the `diff_buf_win_enter` hook replaces diffview's "OURS/THEIRS" winbars with role labels;
  - diffview keymaps bind `<leader>gCo`/`gCt`/`gCb`/`gC0` to `conflict_choose(state.git_side(role))`, so the same keys keep the same role there too.
- **Next steps:**
  - stage: `git add -- <file>`, refused while the buffer or file has markers;
  - continue: `git -c core.editor=true <merge|rebase|cherry-pick|revert> --continue`, refused while the unmerged set is non-empty;
  - skip: `git rebase --skip`;
  - abort: `git <op> --abort` after `vim.fn.confirm`.

  After each: `:checktime` and a state refresh. For a stash conflict, "continue" explains that the resolved changes are in the working tree and that git kept the stash entry.
- **Statusline widget** registered through `plugins.lualine.register`, rendering from cached state only (no work at draw time).

## Risks / Trade-offs

- [Role words differ from git documentation the user may read] → The explain panel (`?`, `<leader>gC?`) always shows the mapping to git's terms for the current operation.
- [Behaviour change of `<leader>gCo`/`gCt` during rebases] → Intentional and stated in the proposal. Merges behave as before.
- [Parsing edge cases (nested markers in docs, CRLF)] → Markers must start at column 0 with exactly seven characters, matching git. CRLF is stripped before matching. Tests cover diff3, zdiff3 and a Markdown file containing a fenced example of markers outside any conflict.
- [`core.editor=true` accepts git's default merge message] → Stated in the spec. Amend with lazygit or commitsmith if a custom message is needed.
