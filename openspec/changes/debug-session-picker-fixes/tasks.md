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
