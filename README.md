# Neovim config

Modern Neovim **0.12+** configuration built on native features: `vim.pack` for plugins,
`vim.lsp.config`/`vim.lsp.enable` for LSP, copilot.lua for Copilot ghost text, and
Sidekick for AI CLI workflows, and commitsmith for AI commit messages. Fully typed with LuaCATS
annotations, checked by lua_ls + lazydev.

## Requirements

- Neovim ≥ 0.12, git, ripgrep, fd, make + a C compiler
- `tree-sitter` CLI ≥ 0.26 (parser compilation)
- Node.js ≥ 22 (copilot-language-server)
- Optional AI CLIs: `claude`, `codex`, or `copilot` — used by Sidekick and by commit-message generation; `tmux` is used for persistent Sidekick sessions when available
- lazygit (floating git UI)
- A Nerd Font in your terminal

## First launch

1. `nvim` — vim.pack clones all plugins, mason installs tools, treesitter compiles parsers.
   Wait for it to settle, then `:restart`.
2. **Copilot sign-in** (one time): open any file and run `:Copilot auth`, then follow the
   device-code flow in the browser. Inline Copilot suggestions use this auth.
   Sidekick uses whichever AI CLI you select with `<leader>as`.
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

Per project (cwd): auto-session saves the session automatically on exit and restores it
automatically when Neovim starts with no file arguments (buffers, layout, and bufferline
pins — pins ride in the session via the `globals` sessionoption plus a post-restore
re-sync). Neo-tree's expanded folders and open/closed state persist beside the session
and are reapplied on restore. DAP breakpoints (line/condition/log) persist separately to
`stdpath('state')` via the workspace module and reappear per file on open, session or not.

## Plugin updates

`<leader>pu` (or `:lua vim.pack.update()`) → review buffer → `:write` to apply, `:quit`
to discard. `nvim-pack-lock.json` is committed; treat it like a lockfile.

## Key bindings (leader = space)

| Prefix | Group |
|---|---|
| `<leader>f` | find: files `<leader><leader>`, resume `ff`, grep `fg`, buffers `fb`, recent `fr`, diagnostics `fd`, TODOs `ft`, notifications `fn` |
| `<leader>g` | git: lazygit `gg`, stage hunk `gs`, reset `gr`, preview `gp`, blame `gb`, draft commit msg (in gitcommit) `gm`, commit msg chat (in gitcommit) `gc`, configure commit AI (in gitcommit) `gM` |
| `<leader>d` | debug: continue `dc`/`F5`, breakpoint `dd`/`B`, groups: breakpoints `db*`, step `ds*` (+`F9/F10/F11`), windows `dw*`, UI `du*` (toggle `duu`), REPL `dr*` (clear `drx`, highlighted), sessions `dS*`, launch `dl*`, eval `de/dE`, hover `dh`, virtual text toggle `dv` (persisted) |
| `<leader>c` | code: format `cf`, diagnostics float `cd`, inlay hints `ci` (LSP: `gd`, `grr`, `grn`, `gra`, `K`) |
| `<leader>b` | buffers: pin `bp`, close others `bo`, delete `bd`/`xw`, close all `xa` / others `xA` (keep pinned+unsaved; cycle: `Tab`/`S-Tab`, `S-h`/`S-l`) |
| `<leader>o` | tasks: run `or`, list `ot` (.vscode/tasks.json supported) |
| `<leader>k` | trouble: diagnostics `kd`/`kD`, loclist `kl`, quickfix `kq`, LSP panel `kw`, symbols `ks` |
| `<leader>l` | lsp: code action `la`, rename `lr`, signature `lk`, outline `lo`, diagnostics `ld*`, workspace `lw*`, calls `lh*`, inlay toggle `li`, codelens `lc*` |
| `<leader>x` | close: buffer `xw`, all `xa`, others `xA` (keep pinned/unsaved) |
| `<leader>u` | ui: theme `ut`, rainbow toggle `ur`, format-on-save `uf`, AI toggle `ua`, undotree `uu`, live diagnostics `ud` (persisted; default: open/save/insert-leave) |
| `<leader>a` | ai: Sidekick CLI toggle `aa`, select `as`, focus `af`, prompt picker `ap`, explain `ae`, review `ar`, diagnostics `ad`/`aD`, commit msg `am` (`gitcommit` buffers auto-insert generated text), commit msg chat `ac`, configure commit AI `aM` |
| `<leader>s` | replace: project `sr`, word `sw` |
| `<leader>q` | session (auto-session; auto-saves on exit, auto-restores on plain `nvim`): save `qs`, restore `qr`, search `ql`, delete `qd`, toggle autosave `qt` |
| `<leader>T` | terminal (toggleterm, `<C-t>` toggles / `2<C-t>` numbered): toggle `Tt`, horizontal/vertical/float `Th/Tv/Tf`, all `Ta`, 1-4 `T1-T4`, name `Tn`, rename `Tr`, send line/selection `Ts`; in terminal: `jk`/`<C-\>` to normal mode |

### Commit messages

Commit-message generation lives in `lua/commitsmith/` — a self-contained plugin kept in this
repo for now, wired by `lua/plugins/commitsmith.lua`. Everything runs through
`:Commitsmith <subcommand>`:

| Subcommand | What it does |
|---|---|
| `generate` | Read the staged diff and write a Conventional Commits message into the commit buffer. Outside a `gitcommit` buffer it hands the prompt to Sidekick instead. |
| `chat` | Toggle the conversation window. Opening it with nothing to show starts a generation. |
| `harness` | Pick the agent CLI — `claude`, `codex` or `copilot` — then a model for it. |
| `model` | Pick a model for the current harness, including a free-text custom id. |
| `lean` | Toggle invoking the harness with no tools and no MCP servers. |
| `stop` | Cancel an in-flight generation. |
| `clear` | Empty the conversation and start over. |
| `accept` | Write the latest revision to the buffer (only needed when `apply = "manual"`). |

In the conversation window: `i` to type a refinement, `s`/`d`/`t`/`r` for canned ones
(shorter, more detail, fix type/scope, regenerate), `<Tab>` to expand the staged diff, `x`
stop, `c` clear, `q` close. Each completed revision replaces the message in the commit
buffer.

The harness, its model, and the lean flag are global and persisted to
`stdpath("data")/commitsmith/settings.json`, re-read on every access so two Neovim
instances stay in step. Lean mode is off by default; it drops the agent's tool surface,
which is pure overhead when the diff is supplied inline. Note that `codex` emits no
incremental output, so its replies arrive whole rather than streaming.

Editing: multi-cursor `<C-n>` (skip with `q`), flash jump `s`, surround `ys/cs/ds`,
references `]]`/`[[`, hunks `]h`/`[h`, inline AI (copilot.lua, sign in with
`:Copilot auth`): accept line `<C-t>`, word `<C-w>`, all `<M-l>`, dismiss `<C-]>`,
cycle `<M-]>`/`<M-[>` — `<C-w>` is a no-op without a suggestion, `<C-t>` falls back
to its builtin (`<C-c>` acts as `<Esc>` so ghost text always clears).
Escape insert with `jk`/`jj` (lag-free, insert-only — terminals unaffected).
Save `<C-s>` (normal+insert), save without formatting `<C-a>`, clear search `<C-x>`/`<Esc>`, tmux-aware window
navigation `<C-h/j/k/l>` (vim-tmux-navigator). Cmdline renders at the bottom row;
macro recording shows a red `REC @reg` indicator in the statusline.
