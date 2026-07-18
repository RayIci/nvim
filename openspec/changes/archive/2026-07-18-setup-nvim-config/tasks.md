## 1. Environment & Skeleton

- [x] 1.1 Verify prerequisites: git, ripgrep, fd, make/cc, lazygit, Node.js ≥ 22 (report any missing and how to install on this WSL2 system)
- [x] 1.2 Create config skeleton: `init.lua`, `lua/config/{options,keymaps,autocmds}.lua` with sensible defaults (leader = space, options incl. `sessionoptions`, base keymaps) — all modules LuaCATS-annotated
- [x] 1.3 Create `lua/config/pack.lua` with the full `vim.pack.add()` plugin list (pin nvim-treesitter `main`, blink.cmp stable tag, noice); verify vim.pack usage against `:help vim.pack`
- [x] 1.4 Implement typed `lua/config/prefs.lua` (JSON get/set/toggle in `stdpath('state')/prefs.json`)

## 2. Language Pack Framework

- [x] 2.1 Implement `lua/langs/init.lua` loader with `---@class LangPack` typed contract: glob `lua/langs/*.lua`, merge `treesitter`/`lsp`/`formatters`/`linters`/`dap`/`mason` fields, expose merged results
- [x] 2.2 Write example packs `lua/langs/lua.lua` (lua_ls + stylua + lazydev) and `lua/langs/python.lua` (basedpyright + ruff + debugpy)

## 3. Core Subsystems (fetch each plugin's current README before configuring)

- [x] 3.1 mason.nvim + mason-tool-installer wired to the merged `mason` list
- [x] 3.2 Treesitter (`main` branch API): install parsers from merged list, start highlighting + `indentexpr` per filetype via autocmd; guess-indent.nvim for indent-style detection
- [x] 3.3 LSP: `vim.lsp.config('*')` capabilities, per-server configs from packs, `vim.lsp.enable()`, `LspAttach` keymaps; native `vim.diagnostic` config with navigation keymaps
- [x] 3.4 blink.cmp: LSP/path/snippets/buffer sources, friendly-snippets, VSCode-like kind icons + menu columns, documentation auto_show while cycling, signature help enabled
- [x] 3.5 conform.nvim with merged `formatters_by_ft`, format keymap + format-on-save with LSP fallback
- [x] 3.6 nvim-lint with merged `linters_by_ft`, autocmd on save/insert-leave
- [x] 3.7 nvim-dap + dap-ui: run pack `dap` registrars, `<leader>d` keymaps, UI auto open/close
- [x] 3.8 noice.nvim (+nui.nvim): markdown-rendered LSP hover/signature docs, cmdline popup, message routing; keep blink's own completion-doc window

## 4. VSCode Interop & Workspace State

- [x] 4.1 `dap.ext.vscode` loading of `.vscode/launch.json` with adapter type mapping from language packs
- [x] 4.2 overseer.nvim: tasks.json provider, task picker keymaps, DAP integration for `preLaunchTask` (verify current API)
- [x] 4.3 Implement typed `lua/config/workspace.lua`: per-cwd JSON state file; breakpoint capture via `dap.breakpoints` + DAP listeners + `VimLeavePre`; per-file restore on `BufReadPost`
- [x] 4.4 Workspace sessions: `:mksession!` auto-save on `VimLeavePre` (plugin windows closed first), `:WorkspaceRestore` command + `<leader>qs` restoring buffers/layout, then breakpoints, then bufferline pins

## 5. AI Features

- [x] 5.1 copilot-language-server via mason, enable as LSP server, `vim.lsp.inline_completion.enable()` + accept/cycle keymaps; document sign-in step
- [x] 5.2 CopilotChat.nvim setup + gitcommit buffer keymap generating commit message/description from staged diff

## 6. Git

- [x] 6.1 gitsigns.nvim with hunk keymaps and blame toggle under `<leader>g`
- [x] 6.2 Floating-terminal lazygit on `<leader>gg` (plugin-free, auto-close on exit)

## 7. UI Shell

- [x] 7.1 Themes (catppuccin, tokyonight, kanagawa, gruvbox, rose-pine, nightfox, onedark, everforest, nord) + themery.nvim (persists to its own state file — no config-block writing in current version), keymap `<leader>ut`
- [x] 7.2 telescope.nvim + fzf-native (build & verify) with `<leader>f` pickers
- [x] 7.3 which-key.nvim with named groups for all leader prefixes (find, git, debug, code, ui, trouble, buffers, tasks, session)
- [x] 7.4 neo-tree.nvim (`<leader>e`), lualine.nvim, trouble.nvim (`<leader>x`), todo-comments.nvim, indent-blankline.nvim
- [x] 7.5 bufferline.nvim: diagnostics indicators, close buttons, pin keymap `<leader>bp`, pinned group; pin persistence via vim.g.BufferlinePinnedBuffers round-trip in workspace module
- [x] 7.6 Undotree keymap (`<leader>uu` → built-in `:Undotree`)

## 8. Editing QoL

- [x] 8.1 nvim-surround, nvim-autopairs (blink integration + newline-between-brackets), flash.nvim
- [x] 8.2 rainbow-delimiters.nvim with prefs-persisted toggle keymap (`<leader>ur`)
- [x] 8.3 vim-visual-multi: default `<C-n>`/`q` mappings, silent exit config
- [x] 8.4 vim-illuminate with next/prev reference keymaps
- [x] 8.5 grug-far.nvim find-and-replace on `<leader>sr`

## 9. Verification

- [x] 9.1 Headless smoke test: clean boot (no startup errors), checkhealth clean (only optional-runtime warnings)
- [x] 9.2 End-to-end Lua + Python check: lua_ls/basedpyright/ruff attach, diagnostics publish, stylua formats via conform, treesitter highlight+indent active, blink capabilities injected (fixed: added .stylua.toml root marker — lua_ls stays silent in single-file mode)
- [x] 9.3 Typing check: intentional `---@type integer = string` surfaces assign-type-mismatch diagnostic in config workspace
- [x] 9.4 DAP check: debugpy session stops at breakpoint; launch.json config listed (auto-loaded — removed deprecated load_launchjs); overseer ran preLaunchTask before launch
- [x] 9.5 Workspace-state check: breakpoints (incl. condition) survive clear+BufReadPost restore; session round-trip restores buffers; pins ride vim.g.BufferlinePinnedBuffers (bufferline SessionLoadPost hook)
- [x] 9.6 Git & AI check: gitsigns attaches in test repo; lazygit installed + float code verified; Copilot sign-in (`:LspCopilotSignIn`) documented in README — actual sign-in/generation needs interactive auth by the user
- [x] 9.7 UI/QoL check: default theme applies, themery persists to state file, rainbow/format-on-save prefs round-trip, all commands registered (fixed: `packadd nvim.undotree`); noice command registers on UI attach (headless N/A)
- [x] 9.8 git init + committed config with `nvim-pack-lock.json`; README documents language-pack contract, workspace persistence, and keybindings
