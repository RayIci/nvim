# Tasks

## 1. Operation state and roles

- [x] 1.1 Implement `lua/config/conflicts/state.lua` (git-dir discovery including linked worktrees, operation detection by `fs_stat`, one batch of git calls for unmerged files, names, subjects and rebase progress, the role table and `section(role)`/`git_side(role)`); verify with `tests/conflicts.lua` building temporary repositories for a merge, a rebase, a cherry-pick, a revert and a stash pop conflict and asserting the operation, progress and yours/incoming names for each
- [x] 1.2 Wire the detection triggers (VimEnter, FocusGained, DirChanged, TermLeave, own actions) and verify with `NVIM_PROFILE=1` (from `add-runtime-profiling`) that a session with no operation starts no git process from the module

## 2. Inline marking and keys

- [x] 2.1 Implement marker parsing (merge, diff3, zdiff3, CRLF) and inline highlights plus role labels in `lua/config/conflicts/inline.lua`, attached only to unmerged files; verify in `tests/conflicts.lua` that a rebase conflict's labels read `YOURS · <branch>` on the user's commit lines, and that a Markdown file with a fenced marker example outside any operation gets no highlights
- [x] 2.2 Add `lua/plugins/conflicts.lua` with `<leader>gCo/t/b/B/0/n/p/Q/q` and `]x`/`[x`, descriptions naming branches; remove `lua/plugins/git-conflict.lua` and `vim.pack.del` git-conflict.nvim; verify in `tests/conflicts.lua` that `<leader>gCo` during a rebase keeps the user's commit lines and during a merge keeps the current branch's lines, and that which-key descriptions contain the branch names

## 3. Resolve view

- [x] 3.1 Implement the resolve tab (YOURS, INCOMING, RESULT preview with role colouring and context) and the whole-side choices `o`/`t`/`b`/`B`/`x` with `<CR>`, `n`, `p`, `u`, `q`; verify in `tests/conflicts.lua` that `o <CR> t <CR> b <CR>` on a three-conflict file produces the expected content with no markers, and that `u` restores the last conflict with markers
- [x] 3.2 Add portions (`<Space>` on lines and visual ranges, `J`/`K` reorder) and the `e` hand edit; verify in `tests/conflicts.lua` that keeping A1 and B2 and moving B2 up applies `B2, A1`, and that a hand-edited result is written as edited

## 4. Conflict center and next steps

- [x] 4.1 Implement the conflict center float with header, legend, file counts and its keys, plus `<leader>gCC`; verify in `tests/conflicts.lua` that the rendered lines for a two-file merge read "MERGING main into feature" and list both files with counts, and that with no operation a notification says there is nothing to resolve
- [x] 4.2 Implement `<leader>gCa`, `<leader>gCc`, `<leader>gCA` (with confirmation) and rebase skip, with the refusal messages and stash explanation; verify in `tests/conflicts.lua` that staging with markers is refused, continuing with unresolved files is refused, a fully resolved rebase continues to completion, and declining abort leaves the operation in progress
- [x] 4.3 Configure diffview's merge tool (`diff3_mixed`, role winbars, role-mapped `<leader>gC` keys) behind `<leader>gCm`; verify manually during a rebase that each top pane is labelled by role (the pane holding the user's commit reads `YOURS · …`, although it is git's "theirs" pane) and that `<leader>gCo` from a top pane keeps the user's commit
- [x] 4.4 Add the explain panel (`<leader>gC?` and `?`), the "stage it" and "continue" notifications, and the `⚔ <OP> n/m · k files` statusline widget; verify in `tests/conflicts.lua` that the widget renders `⚔ REBASE 2/5 · 3 files` for that state and nothing without an operation, and that resolving the last conflict emits the staging suggestion

## 5. Docs

- [x] 5.1 Write the README's "Resolving conflicts" section (roles by operation, keys, resolve view, center, next steps) and update the `<leader>gC` rows of the keymap table; verify every documented key exists via `:map` in a conflicted buffer of a test repository
