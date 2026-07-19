## Why

Follow-up on keymaps-and-ui-fixes: telescope selections shift right cumulatively on `<C-n>/<C-p>` in every picker (regression on telescope master vs the `0.1.x` branch the old config ran), the DAP workflow lacks the old config's FN keys and full keymap tree, dap-ui force-opens on session start, and sessions neither auto-restore nor bring back buffers/pins (`sessionoptions` lacks `globals` and restore is manual). Pin-aware bulk buffer closing from the old config is also missing, and Copilot inline suggestions need a sign-in nudge to actually appear.

## What Changes

- **Telescope**: the selection right-shift's root cause (found via headless repro): the custom nerd-font `selection_caret` was wider than `entry_prefix`, leaving a residual space on every visited row — fixed with width-matched `❯ ` caret and two-space prefix. Telescope stays on master; a briefly-tried `0.1.x` pin was reverted because that branch calls the `ft_to_lang` API removed in Neovim 0.12, breaking previewers.
- **Diagnostics defaults + persisted live toggle**: linters run on buffer open, save, and insert-leave by default; `<leader>ud` switches to live refresh (display in insert + debounced lint on every change) and persists via the prefs module.
- **Auto commit message**: fresh gitcommit buffers get a headlessly generated conventional title + description inserted automatically (once; amend/reword untouched); `<leader>gm` regenerates.
- **DAP keymaps**: port the old config's scheme — `<F5>` continue (saving all buffers first), `<F9>` step into, `<F10>` step over, `<F11>` step out, plus the `<leader>d` tree: continue/restart/pause/run-to-cursor/terminate/force-close, new-parallel-session, breakpoints group (`db*`, quick `dd`/`<leader>B`), step group (`ds*`), floating UI elements (`dw*`), UI controls (`du*`), REPL group (`dr*`), session management (`dS*`), launch group (`dl*`), eval/hover (`de`/`dE`/`dh`). **BREAKING** (keymaps): replaces the current minimal `<leader>d` maps.
- **dap-ui**: no auto-open on session start (manual toggle); auto-close on terminate/exit stays.
- **Debug virtual text**: nvim-dap-virtual-text shows variable values inline during sessions (old-config `eol` style), with a `<leader>dv` toggle persisted across restarts via the prefs module.
- **Neo-tree session state**: the explorer's expanded folders and open/closed state persist per project and are restored with the session (ported from the old config's neotree state JSON, rewired through auto-session's restore hook).
- **Sessions**: replace the custom `:mksession` flow with auto-session — automatic save on exit and automatic restore when opening Neovim with no file args; `sessionoptions` gains `globals` (and old config's other flags) so bufferline pins round-trip; port the deferred pin re-sync hook after restore. Session keymaps live under `<leader>q`. Custom breakpoint persistence stays.
- **Buffer closing**: pin-aware bulk close — `<leader>xa` close all non-pinned (keep unsaved), `<leader>xA` close others (keep pinned + unsaved + current).
- **Cmdline UI**: noice's centered command-palette popup is replaced with the classic bottom-row cmdline (noice-rendered).
- **Macro visibility**: a red `REC @<reg>` indicator in lualine while recording (refreshed on RecordingEnter/Leave) plus noice routing of showmode messages to notifications, so `q<reg>` recording state is always visible.
- **Terminal**: toggleterm.nvim with the old config's keymaps (`<C-t>` toggle with count support, `<leader>T` group: directions, terminals 1-4, toggle-all, named/rename, send line/selection; terminal-mode `<C-\>`/`jk` escape and `<C-h/j/k/l>` window nav) wrapped in a hook registry (`register_on_create/open/close/stdout/stderr/exit`) other modules can extend.
- **Lang-pack `setup` field**: packs may declare a `setup` function run after subsystem wiring — the python pack uses it to auto-activate the project virtualenv in new terminals (old-config venv-on-terminal pattern, without venv-selector).
- **Notification history**: `<leader>fn` opens the noice message/notification history in a telescope picker.
- **Copilot**: keep the native inline-completion setup; add a sign-in status notification when the copilot server attaches unauthenticated (points to `:LspCopilotSignIn`); old-config keys (`<C-t>` accept, `<C-]>` dismiss, `<M-]>`/`<M-[>` cycle) and no lingering ghost text when leaving insert with `<C-c>` (insert-mode `<C-c>` remapped to `<Esc>` so InsertLeave fires).

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `ui-shell`: session requirement changes from plugin-free `:mksession` to auto-session with automatic save/restore and pin re-sync.
- `debugging`: keymap requirement expands to old-config scheme incl. FN keys; dap-ui no longer auto-opens on session start.
- `core-keymaps`: adds pin-aware bulk buffer-closing keymaps.

## Impact

- **Files**: `lua/config/pack.lua`, `lua/config/options.lua`, `lua/plugins/dap.lua`, `lua/config/workspace.lua`, `lua/config/keymaps.lua` or `lua/plugins/bufferline.lua`, `lua/plugins/copilot.lua`, new `lua/plugins/auto-session.lua`, README.
- **Dependencies**: +rmagatti/auto-session; telescope.nvim switches branch (plugin re-checkout).
- **Behavior**: sessions auto-restore on plain `nvim` in a project dir; `<leader>d` keymap layout changes wholesale; dap-ui opens only on demand.
