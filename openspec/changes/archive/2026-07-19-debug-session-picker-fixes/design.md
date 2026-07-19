## Context

Diagnosis from live use after keymaps-and-ui-fixes:

1. **Telescope right-shift**: every `move_selection_next/previous` shifts result entries right and the shift accumulates. Old config was immune — its lazy-lock pinned telescope to branch `0.1.x` (`e69b434`); this config runs master (`v0.2.2-28`). The regression lives in master's caret/entry redraw. User asked for the old-config-aligned solution.
2. **DAP UX**: current `<leader>d` maps are a minimal subset; the old config (`.backup/config/keymaps/dap.lua`) has the full scheme the user wants, including FN keys and multi-session management. dap-ui auto-opens via `event_initialized` listener — unwanted.
3. **Sessions**: custom workspace module saves a session only on `VimLeavePre` and restores only via `<leader>qs`; `sessionoptions` lacks `globals`, so `vim.g.BufferlinePinnedBuffers` never lands in the session file and bufferline's `SessionLoadPost` re-pin has nothing to read. User wants automatic save AND automatic restore, buffers included, pins included. Old config used rmagatti/auto-session with a deferred `load_pinned_buffers` post-restore hook.
4. **Bulk closing**: old config's `<leader>xa`/`<leader>xA` use bufferline's `groups._is_pinned` to protect pinned buffers.
5. **Copilot inline**: native `vim.lsp.inline_completion` wiring exists and stays (user decision); suggestions won't render until `:LspCopilotSignIn` has been run once.

## Goals / Non-Goals

**Goals:**
- Stable telescope selection rendering in all pickers.
- Old-config DAP keymap parity (FN keys + `<leader>d` tree), manual dap-ui.
- Sessions: auto-save, auto-restore (no-args launch), buffers + window layout + bufferline pins restored.
- Pin-aware bulk buffer closing.
- Copilot ghost text working with a clear sign-in path.

**Non-Goals:**
- No scope.nvim / per-tab buffer scoping, no overseer task persistence, no neo-tree state or quickfix persistence from the old session config (start minimal; add later if missed).
- No telescope-live-grep-args / undo / project.nvim extensions.
- No copilot.lua plugin.
- Old `<leader>dS` session-terminate duplicates (`dSq`/`dSQ`) reduced to the useful set.

## Decisions

**D0 — Telescope shift root cause (supersedes D1, which is withdrawn).** A headless repro (drive `find_files`, step `move_selection_next`, diff buffer lines) showed every visited row permanently gaining one leading space. Cause: `selection_caret = "<nerd-icon> "` renders wider than the 2-cell default `entry_prefix`; telescope re-renders rows on selection moves and restores the prefix with the width difference left behind. Fix: width-matched `selection_caret = "❯ "` + explicit `entry_prefix = "  "`, verified by re-running the repro (constant columns). The D1 `0.1.x` pin was reverted: that branch calls `vim.treesitter.language.ft_to_lang()`, removed in Neovim 0.12, crashing previewers (`attempt to call field 'ft_to_lang'`); telescope runs on master, where the repro confirms stable rows with the caret fix.

**D11 — Diagnostics: one persisted "live" pref drives both engines.** `diagnostics_live` (prefs module, default off) controls `vim.diagnostic` `update_in_insert` (set at startup, flipped by `<leader>ud`) and nvim-lint's `TextChanged`/`TextChangedI` autocmds (gated at event time, 400ms debounce). Baseline lint triggers (`BufReadPost`, `BufWritePost`, `InsertLeave`) always run, so diagnostics appear on open without saving.

**D12 — Commit messages auto-insert.** The existing headless CopilotChat flow now fires automatically on `FileType gitcommit` when the first line is blank (fresh commit) and once per buffer (`b:copilot_commit_generated` guard); amend/reword buffers arrive with a message and are skipped. `<leader>gm` stays for manual regeneration.

**D1 — Pin telescope to branch `0.1.x`.** `{ src = ..., version = "0.1.x" }` in vim.pack, matching the old config's working state. Alternative (pin master commit before the regression) rejected: unknown bisect cost; `0.1.x` is telescope's maintained stable branch and proven in the old setup. fzf-native and ui-select both support 0.1.x.

**D2 — DAP keymaps ported wholesale into `plugins/dap.lua`.** FN keys: `<F5>` continue (after `silent! wall`), `<F9>` into, `<F10>` over, `<F11>` out. Groups: `db*` breakpoints (`dbb` toggle, `dbB` conditional via `vim.ui.input`, `dbl` logpoint, `dbc` clear all, `dbs` list), quick toggles `dd` and `<leader>B`; `ds*` steps (incl. `dsb` step back); `dw*` full-screen float elements (repl/console/scopes/breakpoints/stacks/watches); `du*` UI (`duu` toggle, `duo` open, `duc` close, `dur` reset layout); `dr*` REPL (open/close/toggle/run-last); `dS*` sessions (switch picker, widget, next/prev focus); `dl*` launch (`dll` run last, `dlc` pick config, `dln` new parallel session with `internalConsole`); top-level `dc` continue, `dR` restart, `dp` pause, `dC` run to cursor, `dq` terminate, `dQ` force close (+ dap-terminal buffer cleanup), `de`/`dE` eval, `dh` hover widgets. which-key subgroups registered for `db/ds/dw/du/dr/dS/dl`. All keymaps under `<leader>d` are replaced — the old scheme wins on conflicts (`dl` was logpoint, now launch group).

**D3 — dap-ui manual open.** Delete the `event_initialized` open listener; keep `event_terminated`/`event_exited` close listeners so a finished session tidies up. `duu` toggles on demand.

**D3b — DAP virtual text with persisted toggle.** theHamsta/nvim-dap-virtual-text (old config's `virt_text_pos = "eol"`), initialized with `enabled` read from the prefs module (`dap_virtual_text`, default on) — the same persistence pattern as the rainbow-brackets toggle. `<leader>dv` flips the pref and runs `DapVirtualTextEnable/Disable` so the change applies live and survives restarts.

**D4 — auto-session replaces the mksession flow.** New `plugins/auto-session.lua`: `auto_save = true`, `auto_restore = true` (plugin's built-in no-args guard), `show_auto_restore_notif = false`, `post_restore_cmds = { load_pinned_buffers }` — the old config's deferred bufferline pin re-sync (reads `vim.g.BufferlinePinnedBuffers`, pins via `bufferline.groups.add_element`, refreshes UI). `sessionoptions` set to the old config's value (`blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions,globals`) so pins persist inside the session file. `config/workspace.lua` keeps breakpoint persistence (BufReadPost restore + VimLeavePre snapshot) and drops its mksession/restore/`<leader>qs` parts; breakpoint restore after session load keeps working because auto-session's `:source` triggers BufReadPost per restored buffer. Keymaps under `<leader>q` (session group): `qs` save now, `qr` restore, `ql` search picker, `qd` delete, `qt` toggle auto-save. Alternative (fix the custom module: add autosave timer + VimEnter restore + globals) rejected: auto-session is what the user trusts from the old setup and handles cwd/argument edge cases.

**D4b — Neo-tree state rides beside the session.** Port the old config's per-cwd neotree JSON (`{ nodes = expanded-dir-ids, is_open = bool }`, now under `stdpath('state')/neotree/`): saved by a `VimLeavePre` autocmd registered BEFORE `auto-session.setup()` so it snapshots the tree before auto-session's `close_unsupported_windows` closes it; restored in `post_restore_cmds` (covers auto and manual restore) by seeding `state.force_open_folders` and running `neo-tree` `show` only when the tree was open at exit, deferred 200ms like the old config. Differences from the old version: always write the file (so a closed tree is remembered as closed, not stale-open), restore is session-coupled rather than a bare `VimEnter` hook, and the legacy array format shim is dropped.

**D5 — Bulk closing in `plugins/bufferline.lua`.** Port `is_buffer_pinned` (bufferline `state.components` + `groups._is_pinned`) plus `<leader>xa` (delete all non-pinned, unmodified, creating a scratch first so Neovim survives; jump back to a remaining buffer) and `<leader>xA` (delete all except current/pinned/modified). Lives next to bufferline since it depends on its internals.

**D7 — Cmdline back to the bottom; recording made visible.** Noice keeps message routing but `cmdline.view = "cmdline"` (bottom-row, noice-rendered) replaces the `command_palette` preset the user dislikes; `lsp_doc_border` preset dropped as dead config since noice no longer renders LSP docs. Macro recording: noice consumes `msg_showmode`, hiding `recording @x`. Two-part fix: a lualine `lualine_x` component showing `REC @<reg>` in red while `vim.fn.reg_recording() ~= ""`, refreshed by RecordingEnter/RecordingLeave autocmds (statusline doesn't redraw on its own for recording state), and a noice route sending `msg_showmode` events to the notify view as a fallback signal.

**D6 — Copilot sign-in nudge.** On copilot LspAttach, run a `signIn`-status check: if the server reports not signed in, `vim.notify` once pointing to `:LspCopilotSignIn`. No other change to the native wiring.

**D6b — Old-config inline-suggestion keys on the native API.** Buffer-local insert maps on attach: `<C-t>` accept line and `<C-w>` accept word, both via `vim.lsp.inline_completion.get({ on_accept })` — the hook exists to modify the item pre-insertion, so trimming `insert_text` to the first line/word implements partial accepts without the copilot.lua plugin (snippet-typed items fall back to full accept). `<C-]>` dismiss is a buffer-scoped inline-completion disable/enable cycle (clears the ghost extmark; no public dismiss API); `<M-l>` full accept, `<M-]>`/`<M-[>` cycle. `<C-w>`'s built-in delete-word is shadowed only in LSP-attached buffers, as in the old config. `<C-t>` toggleterm's global insert mapping loses to the buffer-local copilot map in LSP buffers — same collision the old config lived with. Lingering ghost text after `<C-c>`: `<C-c>` skips InsertLeave entirely, so the module's cleanup never runs (and the diagnostics deferred refresh breaks too); global insert-mode `<C-c> -> <Esc>` map restores InsertLeave semantics, plus an InsertLeave/BufLeave belt-and-braces cleanup autocmd ported from the old config.

**D8 — Terminal as an extensible module.** `plugins/toggleterm.lua` owns toggleterm.nvim (old-config options: size 20, `<C-t>` open mapping incl. insert/terminal modes, horizontal default, curved float) and a hook registry: `register_on_create/on_open/on_close/on_stdout/on_stderr/on_exit` append to lists; dispatcher closures passed to toggleterm's callbacks iterate the lists pcall-guarded, so hooks registered *after* setup (language packs load later) still fire. Keymaps ported: `<leader>T` group (`Tt/Th/Tv/Tf/Ta/T1-T4/Tn/Tr/Ts`), count-prefixed `<C-t>` handled natively by toggleterm (no explicit `1<C-t>` maps), TermOpen autocmd for buffer-local `<C-\>`/`jk` escape and `<C-h/j/k/l>` wincmd nav.

**D9 — Lang packs get a `setup` extension point.** `LangPack.setup?: fun()` collected by the loader and run after all `apply()` calls, giving packs access to fully-initialized subsystems. Python pack uses it to register a terminal on_create hook that activates `./.venv` or `./venv` (via `nvim_chan_send`, unix path) when no `$VIRTUAL_ENV` is active — the old config's venv-selector integration reduced to convention-based detection, since venv-selector isn't installed here.

**D10 — Notification history via noice's telescope integration.** `<leader>fn` runs `Noice telescope` (message history in a telescope picker, consistent with the `<leader>f` prefix). `<leader>un` (dismiss) stays.

## Risks / Trade-offs

- [telescope 0.1.x is older; some master-only features/extensions may mismatch] → It's telescope's stable branch; fzf-native + ui-select target it; old config ran it daily.
- [auto-session restoring on plain `nvim` may surprise in scratch dirs] → `qt` toggles auto-save; restore only fires when a session exists for the cwd.
- [`sessionoptions` gains `globals`/`localoptions`, persisting more state than before] → Matches the old, known-good behavior; sessions are per-project files in stdpath('data').
- [Old keymap muscle memory replaces the 0.12-native `<leader>d` set] → Intentional; README updated.
- [bufferline `groups._is_pinned` is a private API] → Same usage as old config; guarded with pcall, degrades to treating buffers as unpinned.
