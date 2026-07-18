## Why

The Neovim config directory is empty — there is no editor configuration at all. Alex wants a complete, modern development environment built on Neovim 0.12.4, leveraging its new native capabilities (vim.pack plugin manager, native LSP config, native inline completion) instead of legacy plugin stacks, with an architecture that makes onboarding a new programming language a one-file operation.

## What Changes

- Bootstrap a full Neovim configuration from scratch in `/home/alex/.config/nvim` (init.lua + `lua/` module tree).
- Plugin management via native `vim.pack` with lockfile — no third-party plugin manager.
- Tool installation via mason.nvim + mason-tool-installer (LSP servers, formatters, linters, DAP adapters).
- LSP via native `vim.lsp.config()` / `vim.lsp.enable()` with nvim-lspconfig as the config data source; diagnostics configured through native `vim.diagnostic`.
- Syntax highlighting via nvim-treesitter (`main` branch rewrite).
- Debugging via nvim-dap + nvim-dap-ui; linting via nvim-lint; formatting via conform.nvim.
- Completion via blink.cmp; AI ghost-text via native `vim.lsp.inline_completion` + copilot-language-server (installed through mason — no copilot.lua).
- Copilot-generated commit messages/descriptions via CopilotChat.nvim with a keybind in gitcommit buffers.
- Git integration via gitsigns.nvim + lazygit floating-terminal.
- Theme switcher via themery.nvim with persisted choice (catppuccin, tokyonight, kanagawa).
- Discoverability and navigation: which-key.nvim, telescope.nvim + telescope-fzf-native.
- UI/QoL extras: neo-tree.nvim, lualine.nvim, bufferline.nvim (with pinnable buffers), trouble.nvim, nvim-surround (or mini.surround), flash.nvim, autopairs, todo-comments, indent guides.
- A declarative **language pack framework** under `lua/langs/`: each language is one drop-in file returning `{ treesitter, lsp, formatters, linters, dap, mason }`; a loader fans these out to `vim.lsp.enable`, conform, nvim-lint, nvim-dap, and mason-tool-installer. Ships with example packs (lua, python) to prove the framework.
- **Fully typed config**: all custom Lua modules carry LuaCATS annotations (`---@class`, `---@param`, `---@return`, `---@type`); lazydev.nvim in the lua language pack for Neovim runtime typing.
- Expanded theme set: catppuccin, tokyonight, kanagawa, gruvbox, rose-pine, nightfox, onedark, everforest, nord.
- Rainbow bracket colors via rainbow-delimiters.nvim with a **persisted on/off toggle** backed by a small prefs module (JSON in `stdpath('state')`).
- Automatic indentation: treesitter indent + guess-indent.nvim + autopairs newline-between-brackets handling.
- Rich completion UX: blink.cmp documentation auto-preview while cycling candidates, VSCode-like kind icons and menu layout, signature help while typing, snippets via friendly-snippets.
- Markdown-rendered LSP hover/docs and modern cmdline/message UI via noice.nvim.
- **VSCode interop**: nvim-dap loads `.vscode/launch.json` (`dap.ext.vscode`); overseer.nvim runs `.vscode/tasks.json` tasks and integrates with DAP `preLaunchTask`.
- **Plugin-free workspace-state module** (explicit user requirement — no plugin): per-project JSON persistence of DAP breakpoints (restored per file on reopen and per session), native `:mksession`-based session save/restore of open buffers, and bufferline pinned-buffer restore.
- Multi-cursor editing via vim-visual-multi (`Ctrl+n` add occurrence, `q` skip, live region highlighting).
- Reference navigation via vim-illuminate (next/prev reference keymaps); project-wide fuzzy find-and-replace via grug-far.nvim.

## Capabilities

### New Capabilities
- `plugin-management`: Declarative plugin installation, pinning, and updates via native vim.pack; external tool installation via mason.
- `lang-pack-framework`: One-file-per-language registration of treesitter parsers, LSP servers, formatters, linters, DAP adapters, and mason tools, with a loader that wires each field to its subsystem.
- `lsp-and-diagnostics`: Native LSP enablement with sensible keymaps, capabilities integration with completion, and configured vim.diagnostic presentation.
- `editing-experience`: Treesitter syntax, blink.cmp completion (VSCode-like icons, doc auto-preview, signature help, snippets), AI inline completion (copilot-language-server), formatting on demand/save (conform), linting (nvim-lint), surround/autopairs/flash motions, rainbow brackets with persisted toggle, automatic indent, multi-cursor, reference navigation, fuzzy find-and-replace.
- `debugging`: nvim-dap + dap-ui with adapters registered through language packs, breakpoint/step keymaps, `.vscode/launch.json` support, overseer task runner with `preLaunchTask` integration, and plugin-free breakpoint persistence.
- `git-integration`: gitsigns hunks/blame, lazygit floating terminal, Copilot-generated commit messages in gitcommit buffers.
- `ui-shell`: Theme switcher with persistence (9 famous themes), lualine statusline, bufferline with pinnable buffers, neo-tree explorer, telescope pickers, which-key discoverability, trouble diagnostics panel, todo-comments, indent guides, noice cmdline/hover UI, plugin-free session restore (open buffers + pins), undotree.

### Modified Capabilities

(none — greenfield config, no existing specs)

## Impact

- New files: `init.lua`, `lua/config/*` (options, keymaps, autocmds, prefs module, workspace-state module), `lua/plugins/*` (per-plugin setup), `lua/langs/*` (framework + language packs), `nvim-pack-lock.json` (generated). All custom modules fully LuaCATS-annotated.
- State files (generated at runtime, per project): workspace-state JSON and prefs JSON under `stdpath('state')`, session files via `:mksession`.
- External dependencies: git (vim.pack), Node.js ≥ 22 (copilot-language-server), lazygit binary, ripgrep + fd (telescope), a build toolchain for telescope-fzf-native, GitHub Copilot subscription for AI features.
- Neovim 0.12.4 required — config uses 0.12-only APIs (vim.pack, vim.lsp.inline_completion, 'autocomplete'-era LSP idioms) and must avoid deprecated patterns.
- No existing config is modified or removed (directory is currently empty).
