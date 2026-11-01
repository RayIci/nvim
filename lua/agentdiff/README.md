# agentdiff

Review file changes made by AI agents running outside Neovim, the way VS Code's
agent mode does. An agent (Claude Code, Copilot CLI, Codex, …) runs in another
tmux pane and writes straight to disk. agentdiff shows every one of those
changes inline as a pending diff, which you can step through and **keep** or
**undo** per change, per file or all at once. Edits you make in Neovim are
never part of the review.

No agent needs any configuration: a change on disk that Neovim did not make is
the agent's.

## Requirements

- Neovim 0.12 or newer
- `git` on `PATH`. It's used only as a content store in a private directory;
  your project doesn't have to be a git repository, and if it is, agentdiff
  never writes to its `.git`.

No other plugins.

## Setup

```lua
require("agentdiff").setup({
  -- No keymaps are created unless you pass them.
  keymaps = {
    next = "]a",
    prev = "[a",
    keep = "<leader>rk",
    undo = "<leader>ru",
  },
})
```

### Options

| Option | Default | Meaning |
|---|---|---|
| `keymaps` | `false` | table of `action = lhs` (`next`, `prev`, `next_file`, `prev_file`, `keep`, `undo`, `keep_file`, `undo_file`, `keep_all`, `undo_all`, `panel`, `view`, `overlay`, `resolve`); `keep`/`undo` are also mapped in visual mode |
| `poll_interval` | `1000` | ms between disk checks while Neovim is focused (`0` disables the timer) |
| `settle` | `300` | ms an unclaimed change waits before it's confirmed as the agent's |
| `claim_ttl` | `10000` | ms an unused claim stays valid |
| `max_file_size` | `1 MiB` | larger files are reviewed as whole files |
| `max_files` | `20000` | larger projects are not reviewed (with a notice) |
| `excludes` | build/cache dirs | gitignore-style patterns never reviewed, on top of `.gitignore` |
| `root` | git toplevel or cwd | force the project root; the home directory and `/` are never used unless forced |
| `confirm` | `true` | ask before keep-all / undo-all |
| `hint` | `true` | show the hint on the change nearest the cursor |
| `auto_start` | `true` | start on setup (on `VimEnter`) |

## Lua API

Every action is a function on `require("agentdiff")`:

| Function | What it does |
|---|---|
| `setup(opts)` | configure; starts reviewing unless `auto_start = false` |
| `start()` / `stop()` | start or stop reviewing the current project (this session only) |
| `enable()` / `disable()` / `toggle()` | turn review on / off, persisted across restarts; turning it back on starts each project clean from its current files |
| `enabled()` | true when review is on |
| `next()` / `prev()` | next / previous pending change, crossing into other files; wraps with a notice |
| `next_file()` / `prev_file()` | next / previous changed file |
| `open(path)` | open a pending file at its first change |
| `keep(opts)` | keep pending changes into the baseline; the file isn't touched |
| `undo(opts)` | restore the baseline of pending changes, on disk |
| `keep_file()` / `undo_file()` | keep / undo every change in the current file |
| `keep_all(opts)` / `undo_all(opts)` | every change in every file; asks first unless `{ force = true }` |
| `resolve(choice)` | resolve a conflicted file: `"agent"`, `"mine"` or `"compare"` (asks when nil) |
| `panel()` | toggle the changed-files panel |
| `toggle_view()` | toggle inline overlay ↔ side-by-side diff for the current file |
| `toggle_overlay()` | hide / show the overlay; nothing is kept or undone |
| `claim(paths)` | the next disk changes to these paths are yours (for tools that write files) |
| `status()` | statusline summary, e.g. `3 files · 7 changes`; `""` when nothing is pending |
| `files()` | pending files in navigation order |
| `path_status(path)` | `"file"` (has pending changes), `"dir"` (contains such a file) or `nil`: cheap enough for every line of a file tree |

`keep(opts)` and `undo(opts)` take:

| Option | Meaning |
|---|---|
| `scope` | `"hunk"` (default): the change under the cursor · `"file"` · `"all"` |
| `range` | `{ first, last }` lines (with `scope = "hunk"`): only the lines of pending changes in that range. Removed lines count as selected when the range starts at or above the change. |
| `path` | project-relative file (default: the current buffer) |
| `force` | with `scope = "all"`, skip the confirmation |

Undo goes through the file's buffer, loading it hidden when needed, so `u`
afterwards brings the agent's change back as pending. When the buffer has
unsaved edits of yours, the undone region is left unsaved with them and
reaches disk on your next `:w`. Undoing a file the agent created deletes it;
undoing a deletion restores the file.

## Command

`:[range]Agentdiff [subcommand]` (default: `panel`), with completion:

| Subcommand | Action |
|---|---|
| `next` / `prev` | next / previous change |
| `next_file` / `prev_file` | next / previous changed file |
| `keep` / `undo` | the change under the cursor; with a range, only those lines |
| `keep_file` / `undo_file` | every change in the current file |
| `keep_all` / `undo_all` | every change in every file (asks first) |
| `panel` | toggle the changed-files panel |
| `view` | toggle inline ↔ side-by-side |
| `overlay` | hide / show the overlay |
| `resolve` | resolve a conflicted file |
| `refresh` | check the disk now |
| `toggle` / `enable` / `disable` | turn review on / off (persisted) |
| `status` | show the pending summary |

Panel keys: `<CR>`/`o` open at the first change · `K`/`U` keep/undo the file ·
`gK`/`gU` keep/undo all · `R` refresh · `q` close.

## Events and statusline

- `User AgentdiffChanged` fires whenever the set of pending changes changes
  (detected, kept, undone, resolved).
- `require("agentdiff").status()` is a statusline component: it returns
  `3 files · 7 changes`, or `""` when nothing is pending. With lualine:

  ```lua
  sections = { lualine_x = { require("agentdiff").status } }
  ```

## Highlights

| Group | Default link | Used for |
|---|---|---|
| `AgentdiffAdd` | `DiffAdd` | lines the agent added or changed |
| `AgentdiffDelete` | `DiffDelete` | removed lines (virtual) |
| `AgentdiffHint` | `Comment` | the hint on the nearest change |
| `AgentdiffConflict` | `DiagnosticWarn` | changes overlapping your unsaved edits |
| `AgentdiffTreeFile` | `DiagnosticWarn` | file-tree mark of a file with pending changes |
| `AgentdiffTreeDir` | `DiagnosticWarn` | file-tree mark of a directory containing one |

## How it decides who changed what

Every file has a **baseline**: the last version you agreed with. Pending
changes are always *baseline → current content*.

- A change on disk that Neovim did not make is the **agent's**: the baseline
  stays, so the change becomes pending.
- Anything Neovim does is **yours**: typing, `:w`, format-on-save, LSP edits,
  shell commands run with `:!`, and tools that call `claim()`. Your edits are
  merged into the baseline too, so they never show up as pending. An edit
  inside a pending change becomes part of that change.
- When git moves HEAD (checkout, pull, reset, stash, commit), files git put
  back to HEAD's content are folded into the baseline instead of flagged.
- A change that only moves a file back toward its committed content (a
  discard: `git restore`, `git checkout -- f`, lazygit's file or hunk
  discard) is yours too. An agent edit moves away from HEAD, so it is shown
  even when the agent stages it.
- Files inside `.git` (commit messages, rebase todos) and ignored files are
  never reviewed, whoever writes them.

## The store

Baselines live outside your project, one directory per project root:

```
stdpath("state")/agentdiff/<hash of the project root>/
  git/            private git directory (objects only, nothing is ever committed)
  baseline.idx    the baseline of every file
  observed.idx    the last disk content agentdiff has processed
  claims/         claims shared by every Neovim instance on the project
  lock/           cross-instance lock while the indexes are updated
  root            the project root, for humans
```

Every Neovim instance on the same project shares it, and it survives restarts,
so pending changes are still there after `:restart` or a crash. git runs with
a sanitized environment (no inherited `GIT_*`, no system or global config) and
never touches your project's `.git`. Paths ignored by your `.gitignore` files
and by the `excludes` option are never reviewed.

The on/off state lives in `stdpath("state")/agentdiff/enabled`, shared by all
projects.

**Resetting is always safe:** delete the store directory (or a project's
subdirectory) and agentdiff rebuilds it from the files currently on disk,
with nothing pending.

## Tests

The suite runs headless, with no test framework:

```sh
nvim --headless -u NONE -l tests/agentdiff/run.lua            # everything
nvim --headless -u NONE -l tests/agentdiff/run.lua merge      # files whose name contains "merge"
```

Each test gets a temp project directory and a temp `XDG_STATE_HOME`; the
command exits non-zero when a test fails.
