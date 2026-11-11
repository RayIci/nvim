# Proposal

## Why

Resolving a merge conflict is currently confusing:
- git-conflict labels the two sides "Current changes" and "Incoming changes" and maps keys to git's *ours* and *theirs*;
- during a rebase git swaps those words: *ours* becomes the branch being rebased onto, *theirs* becomes your own commit. So the labels and keys point at the wrong side exactly when it matters;
- nothing shows what the file will look like once a conflict is resolved;
- the only way to keep part of each side is to take both and delete by hand;
- nothing says what to do next (stage, continue, abort).

The user needs four things:
1. a clear view of what their branch has and what is coming in;
2. a preview of the result;
3. easy keys to accept a side;
4. a way to keep portions of both.

## What Changes

- **Sides are named by role, everywhere:**
  - **yours**: the work of the branch you are on;
  - **incoming**: what the operation brings in.

  Each label carries the real branch or commit name and subject. The words ours/theirs never appear outside the explain panel.
- **Roles follow the operation:**

  | Operation | Yours | Incoming |
  |---|---|---|
  | merge | current branch | merged branch |
  | rebase | your commit being replayed | the branch you are rebasing onto |
  | cherry-pick | current branch | picked commit |
  | revert | current branch | the revert |
  | stash apply/pop | working tree | stashed changes |
- **Inline conflicts.** Conflicted files show both sides highlighted, with role labels on the marker lines, for example `▼ YOURS · feature/login (your commit a1b2c3 "fix login")` and `▲ INCOMING · main (rebasing onto)`.
- **Same keys, now by role.** `<leader>gCo` keeps yours, `<leader>gCt` takes incoming, `<leader>gCb` keeps both (yours first), `<leader>gC0` keeps neither, `<leader>gCn`/`<leader>gCp` move between conflicts, `<leader>gCQ`/`<leader>gCq` list conflicts in quickfix/Trouble.
  - **BREAKING** only during a rebase: `<leader>gCo` and `<leader>gCt` now pick by role, which is the opposite of git's ours/theirs there. Merges behave exactly as before.
  - New: `<leader>gCB` both with incoming first, and `]x`/`[x` next/previous conflict in conflicted buffers.
- **Resolve view (new, `<leader>gCr`).** For the conflict under the cursor it shows three panes:
  - **YOURS** and **INCOMING**: each line with a checkbox;
  - **RESULT**: a live preview of the file around the conflict with the current choice applied, each line coloured by the side it came from.

  Single keys inside it:

  | Key | Action |
  |---|---|
  | `o` / `t` / `b` / `B` / `x` | yours / incoming / both / both, incoming first / neither |
  | `<Space>` | keep or drop the line (or visual selection) under the cursor, for portions of both |
  | `J` / `K` | move a kept line down or up in the result |
  | `e` | edit the result by hand |
  | `<CR>` | apply and go to the next conflict |
  | `n` / `p` | move between conflicts without applying |
  | `u` | undo the last apply |
  | `?` | explain |
  | `q` | close |
- **Conflict center (new, `<leader>gCC`).** Shows:
  - the operation in plain words (e.g. "REBASING feature/login onto main, commit 2 of 5");
  - which side is which;
  - the conflicted files with their remaining conflict counts.

  From there: resolve a file, open diffview's whole-file 3-way view, stage a resolved file, continue, skip (rebase) or abort.
- **Next steps (new keys):** `<leader>gCm` whole-file 3-way view (diffview), `<leader>gCa` stage the file (refused while markers remain), `<leader>gCc` continue the operation (refused while unresolved files remain), `<leader>gCA` abort after confirmation, `<leader>gC?` explain the sides and keys.
- **Guidance:**
  - when a file's last conflict is resolved, a notification offers `<leader>gCa`;
  - when no conflicted files remain, it offers `<leader>gCc`;
  - while an operation is in progress, the statusline shows something like `⚔ REBASE 2/5 · 3 files`.
- **git-conflict.nvim is replaced** by this module, which keeps git-conflict's highlight group names so themes keep their colours.

## Capabilities

### New Capabilities
- `merge-conflicts`: understanding and resolving git conflicts: operation and role detection, inline marking and actions, the resolve view, the conflict center, next-step commands and statusline status.

### Modified Capabilities
- `git-integration`: the git-conflict requirement is removed in favour of `merge-conflicts`.

## Impact

- New: `lua/config/conflicts/` (`state.lua` operation and roles, `markers.lua` parsing, `inline.lua` highlights and actions, `resolve.lua` resolve view, `center.lua` conflict center), `lua/plugins/conflicts.lua` (keymaps, which-key, statusline widget), `tests/conflicts.lua`.
- Removed: git-conflict.nvim, `lua/plugins/git-conflict.lua`.
- Uses diffview's existing merge view for `<leader>gCm`. No new plugin.
- README: a "Resolving conflicts" section.
