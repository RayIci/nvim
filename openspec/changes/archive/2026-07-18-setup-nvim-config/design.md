## Context

`/home/alex/.config/nvim` is empty. Target is Neovim **0.12.4** (LuaJIT), running on WSL2 Linux. Neovim 0.12 ships native features that replace whole plugin categories: `vim.pack` (plugin manager with lockfile), `vim.lsp.config()`/`vim.lsp.enable()` (LSP setup), `vim.lsp.inline_completion` (LSP inlineCompletion request — the protocol copilot-language-server speaks), and `vim.diagnostic`. The design leans on these natives and adds plugins only where they genuinely add value.

All stack choices were made with the user (see proposal). The distinctive architectural requirement is the **language pack framework**: adding support for a new programming language must require creating exactly one file.

## Goals / Non-Goals

**Goals:**
- Complete daily-driver config: LSP, diagnostics, completion (+ AI ghost text), treesitter, DAP, lint, format, git, fuzzy finding, discoverable keymaps, theming.
- One-file-per-language extensibility with zero core-config edits.
- 0.12-idiomatic: no deprecated APIs, no redundant plugins for things core now does.
- Reproducible: vim.pack lockfile committed; mason tools declared in language packs and auto-installed.

**Non-Goals:**
- Lazy-loading micro-optimization (vim.pack has no event/ft DSL; with ~20 plugins, startup is fine; use `vim.schedule`/autocmd loading only if measurably needed).
- Session management, dashboard, note-taking, AI chat beyond commit messages.
- Supporting Neovim < 0.12.

## Decisions

### D1: Plugin management — native vim.pack
Single `vim.pack.add({...})` call in a dedicated module, listing all plugins with pinned `version` where the plugin has unstable APIs (e.g. nvim-treesitter `main`). Lockfile `nvim-pack-lock.json` is the reproducibility mechanism; updates go through `vim.pack.update()`'s review buffer.
*Alternative considered:* lazy.nvim — rejected with user; native is dependency-free and sufficient.

### D2: Config layout
```
init.lua                    -- requires config.* in order
lua/config/options.lua      -- vim.o / vim.opt
lua/config/keymaps.lua      -- global, non-plugin keymaps
lua/config/autocmds.lua
lua/config/pack.lua         -- the single vim.pack.add() list
lua/config/prefs.lua        -- typed persisted-preferences module (D10b)
lua/config/workspace.lua    -- typed workspace-state module (D10c)
lua/plugins/<name>.lua      -- one file per plugin: setup + its keymaps
lua/langs/init.lua          -- language-pack loader
lua/langs/<language>.lua    -- one drop-in file per language
```
`init.lua` requires: options → pack → plugins → langs loader → keymaps/autocmds. Plugin setup files are `require`d explicitly (deterministic order), not auto-globbed, except `lua/langs/` which IS auto-globbed — that's the drop-in contract.

### D3: Language pack contract
Each `lua/langs/<language>.lua` returns:
```lua
return {
  treesitter = { "python" },                            -- parser names
  lsp        = { basedpyright = { settings = {...} } }, -- server -> vim.lsp.config overrides ({} for defaults)
  formatters = { python = { "ruff_format" } },          -- conform formatters_by_ft fragment
  linters    = { python = { "ruff" } },                 -- nvim-lint linters_by_ft fragment
  dap        = function(dap) ... end,                   -- optional; receives nvim-dap module, registers adapter+configs
  mason      = { "basedpyright", "ruff", "debugpy" },   -- mason-tool-installer ensure_installed
}
```
The loader globs `lua/langs/*.lua` (excluding `init.lua`), merges all fragments, then: calls `vim.lsp.config()` per server override and `vim.lsp.enable()` for all servers; passes merged tables to conform and nvim-lint setup; calls each `dap` function; hands the mason list to mason-tool-installer; installs treesitter parsers via nvim-treesitter's `main`-branch `install()` API and enables highlight per filetype.
*Alternative considered:* per-plugin `ftplugin/` files — rejected: scatters one language across many files, the opposite of the requirement. Every subsystem (conform, nvim-lint, mason-tool-installer) natively accepts merged tables, so the loader is pure data plumbing (~100 lines).

### D4: LSP — native, lspconfig as data
nvim-lspconfig is installed only for its `lsp/<server>.lua` config definitions, which `vim.lsp.config()` resolves automatically via runtimepath. Keymaps and per-buffer wiring go in an `LspAttach` autocmd. blink.cmp capabilities are injected via `vim.lsp.config('*', { capabilities = ... })`.

### D5: Inline AI completion — native, no copilot.lua
copilot-language-server installed via mason. Enabled as a normal LSP server; ghost text driven by `vim.lsp.inline_completion.enable()`, with keymaps for accept (`<Tab>` fallback-aware or dedicated key), next/prev suggestion. First use requires `:LspCopilotSignIn` (or the server's sign-in command).
*Alternative considered:* copilot.lua — rejected: duplicates what core now does; one more moving part.

### D6: Commit messages — CopilotChat.nvim
CopilotChat provides the Copilot chat backend and a `commit` prompt context (`#git:staged`). A buffer-local keymap in `gitcommit` filetype inserts a generated conventional-commit message + description. Requires Node ≥ 22 (present: user must verify; task included).

### D7: Theme switcher — themery.nvim
Themes installed as normal packages (catppuccin, tokyonight, kanagawa); themery provides the picker UI and persists the last choice by writing into a designated file block. Keybind under `<leader>ut`.

### D8: Git — gitsigns + lazygit float
gitsigns for hunks/blame/signs with on_attach keymaps. Lazygit opened in a floating terminal via a small custom `vim.fn.jobstart`-free implementation using `vim.system`?? — no: simplest robust approach is a float + `:terminal lazygit` with autocmd to close on exit (~30 lines, no plugin needed). *Alternative:* lazygit.nvim plugin or snacks.nvim — rejected to keep plugin count down; the float is trivial.

### D9: Verification-before-write of plugin APIs
During implementation, before configuring each plugin, fetch its current README/doc (GitHub) and match setup signatures — mandatory for nvim-treesitter `main` (breaking rewrite: `require('nvim-treesitter').install()`, `vim.treesitter.start()` per buffer, no more `configs.setup`), blink.cmp (release-tagged, use `version = 'stable'`-equivalent pin and its `fuzzy.prebuilt_binaries` download), and themery/CopilotChat.

### D10a: Fully typed Lua config
Every custom module (`lua/config/*`, `lua/langs/init.lua`, language packs) carries LuaCATS annotations: `---@class` for the language-pack spec shape and workspace-state schema, `---@param`/`---@return` on every function, `---@type` on non-obvious locals. lazydev.nvim (in the lua language pack) gives lua_ls full Neovim runtime + installed-plugin typing, so annotations are checked live while editing the config itself. lua_ls diagnostics are left strict.

### D10b: Persisted preferences module
`lua/config/prefs.lua` (~40 lines, typed): reads/writes a single JSON file at `stdpath('state')/prefs.json` via `vim.json`. API: `prefs.get(key, default)`, `prefs.set(key, value)` (write-through), `prefs.toggle(key)`. First consumer: rainbow-brackets on/off (`<leader>ur` toggle applies immediately via rainbow-delimiters' enable/disable API and persists). Future toggles (format-on-save, blame, etc.) reuse it.

### D10c: Workspace-state module (plugin-free — explicit user requirement)
`lua/config/workspace.lua`, fully typed, no plugin. Per-project state keyed by sanitized `vim.fn.getcwd()`, stored as JSON at `stdpath('state')/workspaces/<key>.json`, holding:
- **Breakpoints**: `{ [filepath] = { {lnum, condition?, log_message?}, ... } }`. Captured from `require('dap.breakpoints').get()` on change (DAP listeners + `VimLeavePre`); restored two ways: per file on `BufReadPost` (reopening a file brings its breakpoints back even without a session), and wholesale on session restore, via `require('dap.breakpoints').set()`.
- **Pinned buffers**: list of file paths pinned in bufferline. Captured on `VimLeavePre` by querying bufferline's pinned state; re-applied after session restore by re-pinning matching buffers (bufferline exposes pin via `groups` API — exact call verified during apply per D9).
- **Session**: native `:mksession!` to `stdpath('state')/sessions/<key>.vim` on `VimLeavePre` (open buffers, window layout, cwd via `sessionoptions`); `:WorkspaceRestore` command + `<leader>qs` keymap sources it, then restores breakpoints and pins. No auto-restore on plain `nvim` start (explicit restore keeps scratch usage clean) — revisit if user wants auto.
*Alternative considered:* persistence.nvim + a breakpoint plugin — rejected: user explicitly wants no plugin here; native mksession + two JSON blobs is ~120 lines total.

### D10d: noice.nvim for hover/docs/cmdline
LSP hover and signature docs rendered as proper markdown (treesitter-highlighted, concealed syntax) via noice's LSP doc formatter; also modern cmdline popup and message routing. nui.nvim dependency comes along. blink.cmp's own documentation window already treesitter-highlights markdown, so noice's completion-docs override stays off.

### D10e: VSCode interop — tasks and launch configs
- `dap.ext.vscode.load_launchjs()` (bundled with nvim-dap) loads `.vscode/launch.json` before session start, mapping VSCode `type` names to registered adapters (mapping table provided by language packs' `dap` section where needed).
- overseer.nvim reads `.vscode/tasks.json` (its built-in VSCode template provider), `<leader>ot`/`<leader>or` task pickers, and enables DAP integration so `preLaunchTask` in launch.json runs the overseer task before the debug session starts (`require('overseer').setup()` + its dap patch — exact call verified during apply per D9).

### D10f: Multi-cursor — vim-visual-multi
Its stock bindings match the requested UX exactly: `<C-n>` selects word under cursor and each press adds the next occurrence, `q` skips the current occurrence and grabs the next, `Q` removes a region, with live region highlighting while editing. Only theme-matching highlight groups and a which-key label are configured; core mappings stay default to match documentation.

### D10g: Remaining QoL choices
- **bufferline.nvim**: top bufferline with close icons, diagnostics indicators, and pinning (`<leader>bp` toggle pin); pinned state persisted by D10c.
- **vim-illuminate**: highlights other references of the symbol under cursor; `]]`/`[[` jump next/prev reference.
- **grug-far.nvim**: project-wide find-and-replace UI (ripgrep-backed, live preview) on `<leader>sr`.
- **guess-indent.nvim**: detects file indent style; treesitter `indentexpr` handles automatic structural indent; autopairs provides newline-between-brackets expansion.
- **Themes**: catppuccin, tokyonight, kanagawa, gruvbox.nvim, rose-pine, nightfox, onedark.nvim, everforest (neanias), nord.nvim — all registered in themery.
- **Undotree**: keymap `<leader>uu` for 0.12's built-in `:Undotree`.

### D10: Keymap discoverability
which-key registers group names (`<leader>f` find, `<leader>g` git, `<leader>d` debug, `<leader>c` code, `<leader>u` ui, `<leader>x` trouble). Every plugin file declares its own keymaps with `desc` so which-key picks them up.

## Risks / Trade-offs

- [nvim-treesitter `main` branch API churn] → Pin via vim.pack `version`, lockfile committed; loader isolates treesitter wiring in one function.
- [vim.pack has no lazy loading] → Accept slower-but-simple; if startup exceeds ~120ms, wrap heavy UI plugins (neo-tree, CopilotChat) in `vim.schedule` or load-on-command autocmds.
- [copilot-language-server via native inline_completion is a young integration] → Fallback documented: swap to copilot.lua by editing only `lua/plugins/copilot.lua`; language packs unaffected.
- [blink.cmp needs prebuilt fuzzy binary or Rust toolchain] → Pin to a tagged release so prebuilt binaries download; document `cargo` fallback.
- [telescope-fzf-native needs `make` + cc] → Task includes build verification; WSL2 typically has build-essential — verify during apply.
- [Node < 22 breaks Copilot] → Explicit environment-check task before enabling Copilot pieces.
- [themery writes into a config file block (self-modifying)] → Confine its managed block to a tiny dedicated file so the rest of the config is never touched by it.
- [bufferline pin API is semi-internal (`bufferline.groups`)] → Verify exact pin/unpin/query calls against the README during apply (D9); worst case, track pins purely in the workspace module and only re-apply visually.
- [`:mksession` can conflict with plugin windows (neo-tree, dap-ui, noice)] → Set conservative `sessionoptions` (exclude blank/terminal/help), close plugin windows on `VimLeavePre` before saving the session.
- [vim-visual-multi is Vimscript with its own mapping layer; can clash with other `<C-n>`/`q` uses] → Keep VM defaults, avoid mapping `q` globally elsewhere (macro recording remains normal-mode `q` outside VM mode; VM only owns `q` while regions are active).
- [noice replaces core UI paths (cmdline, messages)] → Pin version; if it misbehaves, its scope can be reduced (LSP-docs-only) without touching other plugins.
- [overseer↔dap preLaunchTask coupling depends on both plugins' current APIs] → D9 verification step covers both READMEs; integration isolated in `lua/plugins/overseer.lua`.

## Open Questions

- None blocking. Surround plugin finalized as **nvim-surround** (most popular standalone); autopairs as **nvim-autopairs**; indent guides as **indent-blankline.nvim (ibl)**; todo-comments.nvim for TODO highlighting — all "famous and used" per user's request.
