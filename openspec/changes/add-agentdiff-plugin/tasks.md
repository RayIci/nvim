# Tasks

## 1. Parity check and scaffolding

- [ ] 1.1 With the user, run the VS Code agent-mode experiments (type inside a pending change then Keep; same then Undo; edit outside a change; `Ctrl+Z` after Undo; agent edits a file with unsaved edits) and record the observed behaviour in design.md; update `specs/agent-change-review/spec.md` if any scenario differs, and verify with `openspec validate add-agentdiff-plugin --strict`
- [x] 1.2 Create `lua/agentdiff/` with `init.lua` (`setup(opts)`, no keymaps by default) and `config.lua` (defaults, validation, LuaCATS classes); verify `nvim --headless -u NONE -c 'lua require("agentdiff").setup({})' -c q` exits 0 with no messages
- [x] 1.3 Add the headless test runner `tests/agentdiff/run.lua` (built-in describe/it/assert, temp project dir and temp `XDG_STATE_HOME` per test, non-zero exit on failure) with one smoke test; verify `nvim --headless -u NONE -l tests/agentdiff/run.lua` passes and fails when an assertion is broken on purpose
- [x] 1.4 Add `lua/agentdiff/README.md` describing the plugin's purpose, requirements (Neovim, git) and how to run the tests; verify the documented test command runs as written

## 2. Diff and three-way merge

- [x] 2.1 Implement hunk computation in `merge.lua` over `vim.text.diff` indices (added, removed, changed; empty-file sides for created/deleted files); verify with unit tests for each hunk kind
- [x] 2.2 Implement `merge3(base, ours, theirs)` with ours-wins on overlapping and touching regions, reporting whether overlap occurred; verify unit tests for disjoint edits, overlap, adjacency, insertions at file start/end and empty sides

## 3. Baseline store

- [x] 3.1 Implement `store.lua`: project root resolution (git toplevel or cwd), store dir `stdpath("state")/agentdiff/<hash>/`, sanitized git runner (strip inherited `GIT_*`, explicit `GIT_DIR`/`GIT_WORK_TREE`/`GIT_INDEX_FILE`), `info/exclude` with defaults plus the project's own excludes; verify a test asserts the project's `git status`, index checksum and refs are unchanged after store operations
- [x] 3.2 Implement the background initial snapshot into `baseline` and `observed`, with review inactive until it completes; verify tests for "Large project startup" (setup returns before the snapshot finishes) and "Not a git repository"
- [x] 3.3 Implement B/O operations (read blob, write blob, update entry, remove entry, list changed vs disk, list new files) with `index.lock` retry and backoff; verify unit tests, including "Ignored paths" and a forced lock-contention retry
- [x] 3.4 Document the store layout and the "delete it to reset" guarantee in the README; verify by deleting the store in a test and asserting it's rebuilt from the current disk state

## 4. Detection and attribution

- [x] 4.1 Implement the D3 rule in `review.lua` (agent change: O := disk; user change: B := merge3(O, B, disk), O := disk) and the in-memory display baseline for unsaved buffers; verify tests for "Typing outside agent changes", "Format on save", "Tweak then keep", "Write with pending changes"
- [x] 4.2 Implement `detect.lua`: 1 s focused poll, pause on `FocusLost`, immediate poll on `FocusGained`/`BufEnter`/`VimEnter`, 300 ms confirmation poll, generation numbers, adaptive back-off with a notice, and a `_test.poll_now()` hook; verify tests for "Agent edit from another tmux pane", "File never opened in Neovim", "Live update while watching" (within 2 s), "Agent worked while Neovim was closed"
- [x] 4.3 Implement `claims.lua`: automatic `BufWritePre`/`BufWritePost` write claims, `claim(paths)` journal shared through the store with 10 s expiry, and time-window claims for `:!` and filter commands; verify tests for "Shell command from Neovim", "Tool claims its writes", "Second instance" (two headless instances on one project)
- [x] 4.4 Implement git-guard (stat the project's `.git/HEAD`/`index`/`MERGE_HEAD`, fold files matching the project index or HEAD); verify tests for "Branch switch" and "Commit keeps pending" against a real temp repository
- [x] 4.5 Implement persistence across restarts; verify a test for "Pending survives restart" (tear down and set up again on the same store)

## 5. Buffers with unsaved edits

- [x] 5.1 Handle `FileChangedShell` for loaded buffers (reload unmodified buffers; merge non-overlapping agent writes into modified buffers as one undo block with the cursor preserved; no W12 prompt); verify a test for "Non-overlapping edits merge"
- [x] 5.2 Implement the conflicted state and its resolutions (take agent, keep mine, compare); verify tests for "Conflict is flagged" and "Keep mine", plus take-agent recoverable with `u`

## 6. Inline overlay

- [x] 6.1 Implement `render.lua`: `AgentdiffAdd`/`AgentdiffDelete`/`AgentdiffHint`/`AgentdiffConflict` linked to `DiffAdd`/`DiffDelete`/`Comment`/`DiagnosticWarn`, `virt_lines` for removed lines, line highlights for added lines, debounced re-render, every window showing the buffer; verify tests for "Modified line" and "Buffer text untouched" by inspecting extmarks and buffer lines
- [x] 6.2 Implement the hint with its session-wide position and the registered keys; verify a test for "Hint position"
- [x] 6.3 Implement hide/show of the overlay; verify a test for "Hide and restore"

## 7. Navigation, keep and undo

- [x] 7.1 Implement navigation (next/prev change across files in panel order with wrap notice, next/prev file); verify tests for "Cross into the next file" and "Wrap around"
- [x] 7.2 Implement Keep for hunk, file and all (with confirmation); verify tests for "Keep one change" and "Keep all asks first"
- [x] 7.3 Implement Undo for hunk, file and all (with confirmation), loading unopened files into hidden buffers; verify tests for "Undo one change" and "Tweak then undo"
- [x] 7.4 Implement the undo-seq journal so `u` after an Undo restores the pending change; verify a test for "Undo is undoable"
- [x] 7.5 Implement created/deleted/renamed file handling; verify tests for "Undo a created file" and "Undo a deleted file"
- [x] 7.6 Implement partial keep/undo for a line range; verify a test for "Keep part of a change", plus partial undo
- [x] 7.7 Document the action API and scopes in the README; verify every documented function exists through a test that calls each one

## 8. Panel, side-by-side, binary files and command surface

- [x] 8.1 Implement `panel.lua` (status, `+N −M`, navigation order, open at first change, keep/undo file and all from the panel); verify tests for "Panel lists counts" and "Open from the panel"
- [x] 8.2 Implement `sidebyside.lua` (read-only baseline split in diff mode, toggle back, keep/undo working in both views); verify a test for "Toggle the view"
- [x] 8.3 Implement binary and oversized file handling (1 MiB default limit, configurable); verify a test for "Binary file changed"
- [x] 8.4 Implement `:Agentdiff` with subcommands and completion, the `User AgentdiffChanged` event and `status()`; verify tests for "Subcommand completion", "Change event", "Summary with pending changes", "Nothing pending"
- [x] 8.5 Document the command, event and statusline component in the README; verify a test checks that the subcommand list matches the README table

## 9. Host wiring

- [x] 9.1 Add `lua/plugins/agentdiff.lua` (options, `]a`/`[a`/`]A`/`[A`, `<leader>r` keymaps incl. visual-mode `rk`/`ru` and `rc`, every keymap with `desc`), call it after commitsmith in `lua/plugins/init.lua`, and add the "review" group to `lua/plugins/whichkey.lua`; verify `nvim --headless -c q` starts with no errors and `:map <leader>rk` lists the mapping
- [x] 9.2 Register the statusline widget through the lualine registry; verify by hand that the summary appears with pending changes and disappears when none are pending
- [x] 9.3 Claim oil actions on `User OilActionsPost`; verify by hand that renaming a file in oil leaves nothing pending
- [x] 9.4 Check whether grug-far emits an event after replacing and claim through it, or else wrap its replace action in a time-window claim; record the choice in design.md D12 and verify by hand that a project-wide replace leaves nothing pending
- [x] 9.5 Add `lua/vale/integrations/agentdiff.lua` and register it in the vale integrations index; verify that under vale-night the overlay groups resolve to vale colours (`:hi AgentdiffAdd`) and still hold after `ColorScheme` handlers run

## 11. Fixes from first use

- [x] 11.1 Never review files inside `.git` or ignored paths, even when Neovim writes them, and drop such entries from both indexes at startup; verify tests for "Writing a commit message" and "Saving an ignored file", plus cleanup of a pre-polluted store
- [x] 11.2 Treat changes that only move a tracked file toward its HEAD content as the user's (`merge3(O, disk, HEAD) == HEAD`); verify tests for "Discard in a git client", "Discard one hunk" and "Staged agent edit still shown"
- [x] 11.3 Replace buffer deletion with a layout-preserving wipe (alternate or empty buffer in every window first); verify a test for "Undo the only buffer" with a neo-tree-like side window, and a TUI check in tmux with the real config
- [x] 11.4 Add the persistent enable/disable/toggle (global state file, per-store epoch to restart clean after a disabled period) with `:Agentdiff enable|disable|toggle`; verify tests for "Off survives restart" and "Enabling starts clean", and update the README
- [x] 11.5 Map `<leader>uR` in the host wiring; verify `:map <leader>uR` lists it and that it toggles review in the real config

## 12. Neo-tree

- [x] 12.1 Confirm whether the "file appears and vanishes" flash on save comes from agentdiff by watching the project directory with agentdiff on and off; record the finding in design.md
- [x] 12.2 Hide conform's `.conform.*` temporary files in neo-tree (`never_show_by_pattern`); verify a save of a Markdown file in the real config no longer lists the temp file in neo-tree
- [x] 12.3 Add `path_status(path)` and the `AgentdiffTreeFile`/`AgentdiffTreeDir` highlights to the plugin, with a vale mapping; verify tests for "File and its parents" and "Nothing pending", and document both in the README
- [x] 12.4 Add the neo-tree `agentdiff` component (copied default renderers with the component next to `git_status`) and refresh neo-tree on `User AgentdiffChanged`; verify in the real config in tmux that "Agent edits a file" and "Marks clear after review" hold

## 13. Extraction to its own repository

- [x] 13.1 Copy `lua/agentdiff/` and the tests to `~/Github/agentdiff.nvim` (`lua/agentdiff/`, `tests/`), fixing the runner's and specs' repository paths; verify the full suite passes from the new location and loads the new copy
- [x] 13.2 Load the plugin from the repository in `lua/plugins/agentdiff.lua` (runtimepath, `$AGENTDIFF_DIR`, help tags) and remove the copies from the configuration; verify the real config starts with review ready and the keymaps mapped
- [x] 13.3 Write `doc/agentdiff.txt` and `docs/` (architecture, attribution, detection, merge3, review UI, testing, decisions) with Mermaid diagrams; verify `:help agentdiff` opens with no duplicate tags and every Mermaid block parses
- [x] 13.4 Add `.gitignore`, `Makefile` (`test`, `fmt`, `fmt-check`, `helptags`), `.luarc.json` and `.stylua.toml`; verify `make test` and `make fmt-check` pass

## 10. End-to-end verification

- [ ] 10.1 With Claude Code in a tmux pane next to Neovim, have it edit, create and delete files; verify every change is pending, navigable with `]a`, and resolvable with keep/undo, and that the user's own edits in between never show
- [ ] 10.2 Repeat 10.1 with Copilot CLI with no extra configuration; verify the same behaviour
- [ ] 10.3 With two Neovim instances on the same project, write in one; verify the other shows nothing pending and both show agent changes
- [x] 10.4 Run the full test suite, `stylua --check lua/agentdiff tests/agentdiff`, and `openspec validate add-agentdiff-plugin --strict`; verify all pass

## Workflow follow-up

- Archive the change after the end-to-end checks pass, syncing the `agent-change-review`, `editing-experience` and `vale-engine` specs.
- Publish `~/Github/agentdiff.nvim` and replace the runtimepath line in `lua/plugins/agentdiff.lua` with a `vim.pack` entry.
