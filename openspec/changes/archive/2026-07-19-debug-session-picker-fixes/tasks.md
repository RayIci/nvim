## 1. Telescope pin

- [x] 1.1 ~~Pin telescope to 0.1.x~~ REVERTED: 0.1.x calls ft_to_lang (removed in 0.12), breaking previewers; telescope back on master, shift fixed by caret width instead (12.1)
- [x] 1.2 Verify pickers open and `<C-n>/<C-p>` render without shifting (headless: confirm checked-out branch; interactive smoke test by user)

## 2. DAP

- [x] 2.1 Rewrite `lua/plugins/dap.lua` keymaps to the old-config scheme (session control, breakpoints `db*` + `dd`/`<leader>B`, steps `ds*`, floats `dw*`, UI `du*`, REPL `dr*`, sessions `dS*`, launch `dl*`, eval `de`/`dE`/`dh`) with which-key subgroups
- [x] 2.2 Add FN keys: `<F5>` continue (wall first), `<F9>` into, `<F10>` over, `<F11>` out
- [x] 2.3 Remove the dap-ui auto-open listener; keep auto-close on terminate/exit

## 3. Sessions

- [x] 3.1 Add rmagatti/auto-session to `lua/config/pack.lua`
- [x] 3.2 Set old-config `sessionoptions` (incl. `globals`) in `lua/config/options.lua`
- [x] 3.3 Create `lua/plugins/auto-session.lua`: auto save/restore, suppressed restore notification, post-restore pinned-buffer re-sync hook; register in `lua/plugins/init.lua`; session keymaps under `<leader>q` (`qs` save, `qr` restore, `ql` search, `qd` delete, `qt` toggle autosave) and which-key group rename
- [x] 3.4 Slim `lua/config/workspace.lua` to breakpoint persistence only (drop mksession/restore/`<leader>qs`); confirm BufReadPost breakpoint restore still fires for session-restored buffers

## 4. Buffer closing

- [x] 4.1 Port pin-aware `<leader>xa` (close all non-pinned, keep unsaved) and `<leader>xA` (close others, keep pinned/unsaved) into `lua/plugins/bufferline.lua`

## 5. Copilot

- [x] 5.1 Add a sign-in status check on copilot attach that notifies with `:LspCopilotSignIn` guidance when unauthenticated

## 6. Wrap-up

- [x] 6.1 Headless verification: clean boot, keymap assertions (FN keys, `dl*`/`db*` groups, `<leader>q*`, `xa`/`xA`), telescope branch check, auto-session loaded
- [x] 6.2 Update README (debug keys, session keys, buffer closing)

## 7. Neo-tree session state

- [x] 7.1 Port neo-tree state persistence into `lua/plugins/auto-session.lua`: VimLeavePre snapshot (expanded dirs + open flag, registered before auto-session.setup) to `stdpath('state')/neotree/<cwd-key>.json`, restore via `post_restore_cmds` (`force_open_folders` + `show` when previously open)
- [x] 7.2 Verify: state file round-trips headless; README session section mentions neo-tree state

## 8. Debug virtual text

- [x] 8.1 Add theHamsta/nvim-dap-virtual-text to pack.lua and set it up in plugins/dap.lua (`eol` position, enabled from prefs `dap_virtual_text` default on) with `<leader>dv` persisted toggle
- [x] 8.2 Verify: plugin loads, toggle flips the pref and the runtime state, README mentions `dv`

## 9. Cmdline & macro visibility

- [x] 9.1 noice.lua: cmdline view "cmdline" (bottom row), drop command_palette and lsp_doc_border presets, route msg_showmode to notify
- [x] 9.2 lualine.lua: red `REC @<reg>` component in lualine_x with RecordingEnter/RecordingLeave refresh autocmds
- [x] 9.3 Verify headless (noice options, recording indicator function, refresh autocmds) and update README

## 10. Terminal & notifications

- [x] 10.1 Add akinsho/toggleterm.nvim to pack.lua; create `lua/plugins/toggleterm.lua` with hook registry + dispatchers, old-config options/keymaps (`<leader>T` group, count-aware `<C-t>`), TermOpen buffer keymaps; register in plugins/init.lua + which-key group
- [x] 10.2 Add `setup` field to the lang-pack framework (LangPack class + loader collect/run after apply)
- [x] 10.3 Python pack: `setup` registers terminal on_create hook activating ./.venv or ./venv when no $VIRTUAL_ENV
- [x] 10.4 Map `<leader>fn` to the noice telescope history picker
- [x] 10.5 Verify headless (toggleterm hook dispatch end-to-end, keymaps, fn picker cmd, lang setup ran) and update README

## 11. Copilot inline keys & Ctrl-C ghost text

- [x] 11.1 keymaps.lua: map insert-mode `<C-c>` to `<Esc>` so InsertLeave fires (fixes lingering ghost text and deferred diagnostics)
- [x] 11.2 copilot.lua: old-config keys on attach — `<C-t>` accept, `<C-]>` dismiss (enable-cycle clear), keep `<M-l>`/`<M-]>`/`<M-[>`; belt-and-braces InsertLeave/BufLeave cleanup autocmd
- [x] 11.3 Verify headless (maps + C-c InsertLeave firing) and update README/design/proposal
- [x] 11.4 Partial accepts via native on_accept hook: `<C-t>` accept line, `<C-w>` accept word, `<M-l>` accept all; update spec/design/README

## 12. Diagnostics defaults, auto commit message, telescope shift

- [x] 12.1 Fix telescope cumulative right-shift: width-matched selection_caret ("❯ ") + entry_prefix; headless repro before/after
- [x] 12.2 lint.lua: baseline BufReadPost/BufWritePost/InsertLeave runs + debounced TextChanged/TextChangedI runs gated on persisted diagnostics_live pref; lsp.lua: update_in_insert follows the pref, <leader>ud toggles and persists it
- [x] 12.3 copilot-chat.lua: auto-generate commit message headlessly when a fresh gitcommit buffer opens (once, skips amend), <leader>gm regenerates
- [x] 12.4 Verify headless and update README + specs (lsp-and-diagnostics, git-integration, ui-shell telescope stability)
- [x] 12.5 Revert the 0.1.x pin (ft_to_lang previewer crash on 0.12); confirm caret fix holds on master via repro; drop plugin-management delta

## 13. Save without formatting

- [x] 13.1 `<C-a>` (n+i) one-shot no-format save via conform format_on_save bypass flag; verified behaviorally with stylua; spec + README updated

## 14. Lazygit responsiveness

- [x] 14.1 Exclude the lazygit float from terminal jk/C-hjkl maps via b:term_no_escape_maps (pending jk map lagged every j press and fast j/k exited terminal mode); keep <C-\> escape; verified per-buffer map sets headless
- [x] 14.2 REPL: <leader>drx clear (dap.repl.clear, verified end-to-end) + nvim-dap-repl-highlights with dap_repl parser in the treesitter install list

## 15. Leader-l LSP tree & leader-k trouble

- [x] 15.1 Move trouble pickers to <leader>k (old-config layout: kd/kD/kl/kq/kw/ks); <leader>x becomes close-only; which-key groups updated
- [x] 15.2 <leader>l LSP command tree on attach: la/lr/lk/lo, ld* diagnostics, lw* workspace folders, lh* call hierarchy (telescope), li global inlay toggle, lc* codelens (run/refresh/toggle) with old-config auto-refresh autocmd; verified on live lua_ls attach

## 16. REPL completion, telescope/neotree hides, advanced yank

- [x] 16.1 blink completes in dap-repl via built-in omni source (per_filetype) + enabled override for that prompt buffer — replaces old blink.compat/cmp-dap/nilguard stack; other prompt buffers stay disabled
- [x] 16.2 Telescope: old-config file_ignore_patterns for find_files and live_grep + --hidden vimgrep args
- [x] 16.3 Neo-tree: old-config hide_by_name/hide_by_pattern/never_show lists and Y advanced-yank path chooser
- [x] 16.4 REPL completion redone: omni-source attempt was kind-less and overlapped the prompt — replaced with old-config blink.compat + cmp-dap (per-filetype dap source for dap-repl/dapui buffers, is_dap_buffer enabled gate, trigger-char nilguard ported)

## 17. Breakpoint persistence at mutation time

- [x] 17.1 Wrap dap.breakpoints set/remove/remove_by_id/toggle/clear with a debounced persist — fixes loss on :restart (VimLeavePre never fires there) and all hard-exit paths; VimLeavePre kept as backstop; verified mid-session writes (add, direct set with condition, removals) and reopen restore
- [x] 17.2 Neo-tree state persists at event time: after_render + window open/close events schedule debounced saves (survives :restart/crash); exiting flag stops auto-session's exit window-teardown from recording is_open=false; never-opened sessions preserve the prior expansion list; all verified mid-session headless
- [x] 17.3 Buffers + pins persist at change time: workspace snapshot (buffers list + vim.g.BufferlinePinnedBuffers) written debounced on BufAdd/BufDelete/BufFilePost and pin toggles; post-restore reconcile re-adds/drops buffers vs the stale session (sparing modified/displayed ones), seeds fresh pin data, and the pin sync now also unpins stale session pins; verified mid-session writes + full stale-session reconcile headless

## 18. Copilot inline engine: copilot.lua

- [x] 18.1 Replace native vim.lsp.inline_completion with zbirenbaum/copilot.lua (old-config engine, mason server binary): real accept_word/accept_line, keys C-t/C-w/M-l/C-]/M-]/M-[, trigger_on_accept=false so accept keys pass through when no suggestion; removed Nvim's default i_CTRL-W map whose rhs recursed through copilot's passthrough into a no-op (root cause of "C-w not working"); sign-in check now recognizes auth.db; verified passthrough deletes word headless
- [x] 18.2 C-w remapped directly to Copilot accept_word (no delete-word fallback, per user preference; no-op without suggestion); i_<S-CR> maps to <CR> so Shift+Enter inserts a newline and stays in insert; both verified behaviorally headless
- [x] 18.3 better-escape.nvim (old-config settings): insert-only jk/jj escape with no pending-map lag; default_mappings off so terminal/cmdline stay untouched (lazygit safety); i_<S-CR> + i_<M-CR> map to <CR> (terminal sends ESC+CR for Shift+Enter, decoded as M-CR, which exited insert); verified headless
