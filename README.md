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
lua/config/pack.lua       the one vim.pack installer + shared libraries
lua/config/keymaps.lua    global keymaps
lua/config/autocmds.lua   global autocmds
lua/config/prefs.lua      persisted preferences (JSON in stdpath state)
lua/config/state.lua      shared JSON state files + debounced, transition-aware saver
lua/config/workspace/     per-project workspace persistence (buffers, breakpoints, pins, explorer, scope)
lua/plugins/<name>.lua    one plugin per file: install spec (M.spec) + setup + its keymaps
lua/plugins/init.lua      ordered list of plugin modules (setup order)
lua/langs/<lang>.lua      drop-in language packs
tests/                    headless checks (`nvim --headless -u NONE -l tests/<file>.lua`)
```

## Workspace persistence (plugin-free)

Per project (cwd): auto-session saves the session automatically on exit and restores it
automatically when Neovim starts with no file arguments (buffers, layout, and bufferline
pins — pins ride in the session via the `globals` sessionoption plus a post-restore
re-sync). Neo-tree's expanded folders and open/closed state persist beside the session
and are reapplied on restore. DAP breakpoints (line/condition/log) persist separately to
`stdpath('state')` via the workspace package and reappear per file on open, session or not.

Buffers, pins, breakpoints, and explorer state also save at mutation time (debounced),
so they survive `:restart` without relying on exit hooks. They live in
`stdpath('state')/workspaces/<cwd-key>.json` (buffers, pins, breakpoints) and
`stdpath('state')/neotree/<cwd-key>.json` (explorer); scope.nvim's per-tab buffer lists ride
in the session file. `lua/config/workspace/` has one module per concern (`buffers`,
`breakpoints`, `pins`, `explorer`, `scope`); `lua/plugins/auto-session.lua` only sets up
auto-session with the package's session hooks. Both state files are written through
`lua/config/state.lua`, which drops a pending write when the directory changes or a
transition pauses persistence.
Managed transitions flush the source snapshots and invalidate pending saves/restores
before resetting editor state. Existing empty snapshots clear stale state; missing
sidecars leave valid session-restored state alone.

## Git worktree workspaces

Worktrees are managed by [git-worktree.nvim](https://github.com/RayIci/git-worktree.nvim),
wired by `lua/plugins/git-worktree.lua`. `<leader>gww` switches the whole workspace in this
Neovim instance, `<leader>gwc` creates a checkout and switches to it, `<leader>gwd` removes
an inactive one; Neogit's status-buffer `w` opens the same menu.

New worktrees default to `<main-checkout>.worktrees/<branch>` (for `/work/client/backend`
and `feature/login`: `/work/client/backend.worktrees/feature/login`), with an editable
destination. Creation never fetches or copies `.env` files and dependencies; set those up
per checkout.

A switch saves the outgoing session and this configuration's workspace state (the
`config.workspace` participant: buffers, pins, breakpoints, neo-tree, scope), then
restores the target's. Unsaved buffers must all be saved or the switch is cancelled (the
default); live Neovim terminal jobs and debug sessions block it. External terminals, tmux,
servers and AI agents keep their working directories. A broken target session puts you
back in the source; see the plugin's README for every safeguard and the recovery rules.
The enabled integrations are auto-session, Neogit, nvim-dap, scope, bufferline and
neo-tree.

`nvim --headless -u NONE -l tests/workspace.lua` runs the end-to-end suite against the
installed plugins (`NVIM_WORKSPACE_TEST_GIT_WORKTREE=~/Github/git-worktree.nvim` tests a
local checkout instead).

## diffbandit (trial)

[diffbandit.nvim](https://github.com/CoreyKaylor/diffbandit.nvim) runs next to diffview
(`<leader>gd`) while it's being tried out, wired by `lua/plugins/diffbandit.lua`. It shows
two panes that keep each side's shape and line numbers, joined by a connector gutter. It
also has a commit panel, a three-pane conflict resolver and folder diffs. In Windows
Terminal the connectors are drawn with Unicode cells: the smooth ribbons need the Kitty
graphics protocol.

- **Keys:** the `<leader>gx` group (table below). Inside its views, `-` stages or unstages
  the hunk or file and toggles amend, in place of diffbandit's `<Space>`, which is the leader
  here. `g?` lists every key of the current window, and `q` closes the view.
- **Version:** it tracks `main` until a release includes `close()`, `:DiffBanditClose` and
  commit-message drafts (v0.3.0 has none of them). The lockfile pins the revision, so
  nothing changes until `vim.pack.update()`. After that release, switch the spec to
  `vim.version.range("0")`.
- **Workspace:** a worktree switch closes every diffbandit view before it checks for unsaved
  buffers, so "Save all and switch" never writes the commit panel's message (writing it
  commits). An unfinished message is kept in memory as a draft and comes back when the panel
  reopens in the same Neovim. Quitting closes the views before the session is saved, but a
  manual `<leader>qs` leaves them open.
- **commitsmith** doesn't attach to diffbandit's commit-message window, which has no
  `gitcommit` filetype. Use Neogit's commit flow (`<leader>gc`) for AI messages.

Load cost: diffbandit is configured the first time one of its commands or keys is used,
not at startup. `nvim --headless -u NONE -l tests/diffbandit.lua` tests the keys, closing,
switches and the exit-time session against the installed plugins.

## Adding a plugin

Create `lua/plugins/<name>.lua` and list `<name>` in `lua/plugins/init.lua` where it should
be set up. The module declares what to install and configures it:

```lua
local M = {}

M.spec = {
  "owner/plugin.nvim",                                   -- GitHub shorthand
  { src = "owner/other.nvim", version = "v1.2.0" },      -- or a full spec (name, version, build)
}

function M.setup()
  require("plugin").setup({})
end

return M
```

`lua/config/pack.lua` collects every module's `M.spec` (after the shared libraries) into one
`vim.pack.add()` before any `setup()` runs, so modules must not `require` a plugin at the top
level. `nvim --headless -u NONE -l tests/plugin-modules.lua` checks that. Language-pack
plugins stay in their pack's `packs` field.

## Themes

`<leader>ut` opens the theme picker (themery); the selection persists. The default,
`vale-night`/`vale-day`, comes from [vale.nvim](https://github.com/RayIci/vale.nvim), which
also provides the theme studio: `:Vale` (or `<leader>uv`), `:Vale new <name>`,
`:Vale edit <name>`. This configuration's own themes (`vale-starter`) live in `themes/`,
with the loaders the studio generates in `colors/` and `lua/lualine/themes/`. Editing the
bundled `vale` theme copies it into `themes/` first, so plugin updates never overwrite it.

## Own plugins

These live in their own repositories and are installed by vim.pack like any other plugin
(pinned in `nvim-pack-lock.json`); this configuration only wires them up:

| Plugin | Wired by |
|---|---|
| [agentdiff.nvim](https://github.com/RayIci/agentdiff.nvim) | `lua/plugins/agentdiff.lua` |
| [commitsmith.nvim](https://github.com/RayIci/commitsmith.nvim) | `lua/plugins/commitsmith.lua` |
| [git-worktree.nvim](https://github.com/RayIci/git-worktree.nvim) | `lua/plugins/git-worktree.lua` |
| [vale.nvim](https://github.com/RayIci/vale.nvim) | `lua/plugins/vale.lua` |

To try unpublished edits, start Neovim with the checkout first on `runtimepath`:
`nvim --cmd 'set rtp^=~/Github/commitsmith.nvim'`.

## Plugin updates

`<leader>pu` (or `:lua vim.pack.update()`) → review buffer → `:write` to apply, `:quit`
to discard. `nvim-pack-lock.json` is committed; treat it like a lockfile.

## Key bindings (leader = space)

| Prefix | Group |
|---|---|
| `<leader>f` | find: files `<leader><leader>`, resume `ff`, grep `fg`, buffers `fb`, recent `fr`, diagnostics `fd`, TODOs `ft`, notifications `fn` |
| `<leader>g` | git: lazygit `gg`, stage hunk `gs`, reset `gr`, preview `gp`, blame `gb`, draft commit msg (in gitcommit) `gm`, commit msg chat (in gitcommit) `gc`, configure commit AI (in gitcommit) `gM` |
| `<leader>gw` | worktrees: switch workspace `gww`, create and switch `gwc`, delete inactive checkout `gwd` (also Neogit status `w`) |
| `<leader>gx` | diffbandit (trial): all changes `gxx`, staged `gxs`, current file `gxf`, commit panel `gxc`, compare branches `gxb`, commit log `gxl`, menu `gxm`, close view `gxq`; in its views `-` stages/toggles amend, `g?` help, `q` close |
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

Commit-message generation comes from [commitsmith.nvim](https://github.com/RayIci/commitsmith.nvim),
wired by `lua/plugins/commitsmith.lua`. Everything runs through `:Commitsmith <subcommand>`:

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

Editing: multi-cursor `<C-n>` (skip with `q`), cursor above/below `<M-Up>`/`<M-Down>`,
rotate cursors `<M-Left>`/`<M-Right>`, flash jump `s`, surround `ys/cs/ds`,
references `]]`/`[[`, hunks `]h`/`[h`, inline AI (copilot.lua, sign in with
`:Copilot auth`): accept line `<C-t>`, word `<C-w>`, all `<M-l>`, dismiss `<C-]>`,
cycle `<M-]>`/`<M-[>` — `<C-w>` is a no-op without a suggestion, `<C-t>` falls back
to its builtin (`<C-c>` acts as `<Esc>` so ghost text always clears).
Escape insert with `jk`/`jj` (lag-free, insert-only — terminals unaffected).
Save `<C-s>` (normal+insert), save without formatting `<C-a>`, clear search `<C-x>`/`<Esc>`, tmux-aware window
navigation `<C-h/j/k/l>` (vim-tmux-navigator), window resize `<C-Up/Down/Left/Right>`.
Cmdline renders at the bottom row; macro recording shows a red `REC @reg` indicator in
the statusline.

### Terminals and Alt+arrows

The multicursor keys `<M-Up/Down/Left/Right>` only work if the terminal passes Alt+arrows
on to Neovim. Some terminals use them for their own shortcuts; unbind those. Every snippet
below is safe to paste even when nothing is bound.

To check, press `<C-v>` in insert mode, then Alt+Up: `^[[1;3A` should appear as text. If
nothing appears, or the terminal reacts instead, the key is still bound.

**Windows Terminal** binds Alt+arrows to moving focus between its panes. Open Settings →
*Open JSON file* and add these to the `"keybindings"` array:

```json
{ "id": null, "keys": "alt+up" },
{ "id": null, "keys": "alt+down" },
{ "id": null, "keys": "alt+left" },
{ "id": null, "keys": "alt+right" }
```

On an older version with no `"keybindings"` array, add them to `"actions"` with
`"command": "unbound"` in place of `"id": null`. Alt+Shift+arrows (resize pane) keep
working.

**tmux** binds Alt+arrows only after the prefix, so nothing is needed unless you added a
`bind -n M-Up …` yourself (this repo's tmux config has none). To make sure, in
`tmux.conf`:

```tmux
unbind -n M-Up
unbind -n M-Down
unbind -n M-Left
unbind -n M-Right
```

**Ghostty** (macOS) binds Alt+Left/Right to word jumps. In `~/.config/ghostty/config`:

```ini
keybind = alt+left=unbind
keybind = alt+right=unbind
macos-option-as-alt = true
```

**kitty**, **WezTerm**, **Alacritty** and **GNOME Terminal** bind nothing to Alt+arrows on
Linux. On macOS, make Option act as Alt:

```conf
# kitty.conf
macos_option_as_alt yes
```

```toml
# alacritty.toml
[window]
option_as_alt = "Both"
```

**Konsole**: in Settings → *Configure Keyboard Shortcuts*, search for `Alt+Up`, `Alt+Down`,
`Alt+Left` and `Alt+Right`, and clear any shortcut using them.

**iTerm2**: in Settings → Profiles → Keys → General, set *Left Option key* to `Esc+`. Under
*Key Mappings*, delete any ⌥←, ⌥→, ⌥↑ or ⌥↓ entries (the *Natural Text Editing* preset
adds ⌥← and ⌥→).

**Terminal.app**: in Settings → Profiles → Keyboard, tick *Use Option as Meta key*, and
delete any ⌥← or ⌥→ entries from the key list.
