# Neovim config

Modern Neovim **0.12+** configuration built on native features: `vim.pack` for plugins,
`vim.lsp.config`/`vim.lsp.enable` for LSP, and `vim.lsp.inline_completion` for Copilot
ghost text (no copilot.lua). Fully typed with LuaCATS annotations, checked by lua_ls + lazydev.

## Requirements

- Neovim ≥ 0.12, git, ripgrep, fd, make + a C compiler
- `tree-sitter` CLI ≥ 0.26 (parser compilation)
- Node.js ≥ 22 (copilot-language-server)
- lazygit (floating git UI)
- A Nerd Font in your terminal

## First launch

1. `nvim` — vim.pack clones all plugins, mason installs tools, treesitter compiles parsers.
   Wait for it to settle, then `:restart`.
2. **Copilot sign-in** (one time): open any file and run `:LspCopilotSignIn`, follow the
   device-code flow in the browser. Both ghost text and CopilotChat need this.
3. `:checkhealth` if anything looks off.

## Adding a language

Drop one file into `lua/langs/<name>.lua` — nothing else. Every field is optional:

```lua
---@type LangPack
return {
  treesitter = { "go" },                        -- parsers
  lsp        = { gopls = {} },                  -- server -> vim.lsp.config overrides
  formatters = { go = { "gofumpt" } },          -- conform, per filetype
  linters    = { go = { "golangcilint" } },     -- nvim-lint, per filetype
  dap        = function(dap)                    -- register debug adapter
    dap.adapters.delve = { type = "server", port = "${port}",
      executable = { command = "dlv", args = { "dap", "-l", "127.0.0.1:${port}" } } }
  end,
  mason      = { "gopls", "gofumpt", "golangci-lint", "delve" },  -- auto-installed
}
```

The loader (`lua/langs/init.lua`) fans these out to `vim.lsp.enable`, conform, nvim-lint,
nvim-dap, mason-tool-installer, and nvim-treesitter. Restart after adding a pack.

## Layout

```
init.lua                  entry point (ordered requires)
lua/config/options.lua    vim options
lua/config/pack.lua       vim.pack plugin list + build hooks
lua/config/keymaps.lua    global keymaps
lua/config/autocmds.lua   global autocmds
lua/config/prefs.lua      persisted preferences (JSON in stdpath state)
lua/config/workspace.lua  plugin-free session/breakpoint/pin persistence
lua/plugins/<name>.lua    one plugin per file: setup + its keymaps
lua/langs/<lang>.lua      drop-in language packs
```

## Workspace persistence (plugin-free)

Per project (cwd): on exit the config saves a `:mksession` session, all DAP breakpoints
(line/condition/log), and bufferline pins to `stdpath('state')`. Reopening a single file
restores its breakpoints immediately; `<leader>qs` (or `:WorkspaceRestore`) restores the
whole session — buffers, layout, pins, breakpoints.

## Plugin updates

`<leader>pu` (or `:lua vim.pack.update()`) → review buffer → `:write` to apply, `:quit`
to discard. `nvim-pack-lock.json` is committed; treat it like a lockfile.

## Key bindings (leader = space)

| Prefix | Group |
|---|---|
| `<leader>f` | find: files `ff`, grep `fg`, buffers `fb`, recent `fr`, diagnostics `fd`, TODOs `ft`, resume `f.` |
| `<leader>g` | git: lazygit `gg`, stage hunk `gs`, reset `gr`, preview `gp`, blame `gb`, commit msg (in gitcommit) `gm` |
| `<leader>d` | debug: breakpoint `db`, conditional `dB`, continue `dc`, step `do/di/dO`, UI `du`, eval `de` |
| `<leader>c` | code: format `cf`, diagnostics float `cd`, inlay hints `ci` (LSP: `gd`, `grr`, `grn`, `gra`, `K`) |
| `<leader>b` | buffers: pin `bp`, close others `bo`, delete `bd` (cycle: `S-h`/`S-l`) |
| `<leader>o` | tasks: run `or`, list `ot` (.vscode/tasks.json supported) |
| `<leader>x` | panels: diagnostics `xx`, buffer `xb`, quickfix `xq`, TODOs `xt` |
| `<leader>u` | ui: theme `ut`, rainbow toggle `ur`, format-on-save `uf`, AI toggle `ua`, undotree `uu` |
| `<leader>a` | ai: chat `aa`, explain `ae`, review `ar` |
| `<leader>s` | replace: project `sr`, word `sw` |
| `<leader>q` | session: restore `qs` |

Editing: multi-cursor `<C-n>` (skip with `q`), flash jump `s`, surround `ys/cs/ds`,
references `]]`/`[[`, hunks `]h`/`[h`, inline AI accept `<M-l>`, cycle `<M-]>`/`<M-[>`.
