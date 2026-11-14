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

## Pickers and messages

All pickers come from [snacks.nvim](https://github.com/folke/snacks.nvim): the `<leader>f`
keys, the LSP lists, `vim.ui.select` (DAP configurations, code actions labelled with their
server, sessions, virtualenvs) and `vim.ui.input`. Inside a picker, type to filter,
`<C-n>`/`<C-p>` or `<C-j>`/`<C-k>` move, `<CR>` opens, `<C-v>`/`<C-s>` open in a
vertical/horizontal split, `<Tab>` selects several, `<C-q>` sends to quickfix, and `<Esc>`
closes. `]]`/`[[` jump between the language server's highlighted references of the word
under the cursor.

Messages use Neovim 0.12's built-in message UI (`vim._core.ui2`). The cmdline stays at the
bottom, and long output such as `:messages` opens in a pager closed with `q`, never a
"Press ENTER" prompt. Notifications are snacks toasts (`<leader>un` dismisses them,
`<leader>fn` lists them). The message UI is experimental; if it misbehaves, turn it off by
setting `"ui2": false` in `stdpath("state")/prefs.json` and restarting.

## File explorer

`<leader>e` toggles the [snacks.nvim](https://github.com/folke/snacks.nvim) explorer
(`lua/plugins/explorer.lua`): a 45-column sidebar that follows the current file and marks
git status, diagnostics and pending agent changes (agentdiff). `nvim .` opens it on that
directory. `<leader>E` opens oil in a float for editing the filesystem as text.

| Key (in the explorer) | Action |
|---|---|
| `<CR>`, `w`, `l` | Open the file (with several editing windows, pick the window by its label); on a folder, expand/collapse |
| `h` / `<BS>` | Collapse the folder / go up to the parent |
| `Y` | Copy the path: filename, stem, absolute, cwd-relative, home-relative or extension |
| `y` / `p` | Yank / paste files |
| `a` `d` `r` `c` `m` | Add, delete, rename, copy, move |
| `n` | New .NET item (class, interface, …) in the folder under the cursor |
| `H` | Show/hide the hide list (`.git`, `.github`, caches, `bin`/`obj`, `node_modules`, `.next`, venvs, `*.egg-info`) |
| `I` | Show/hide git-ignored files (shown by default) |
| `Z` | Collapse all |
| `P` | Toggle the preview |
| `]g` `[g` / `]d` `[d` | Next/previous git change / diagnostic |
| `<C-c>` | Make the folder under the cursor the tab's working directory |
| `/` | Filter the tree |
| `q` | Close |

`__pycache__` and conform's `.conform.*` temporary files are never shown. `<C-h/j/k/l>`,
`<C-s>` and `<C-t>` keep their global meaning inside the explorer. Closing the last editing
window quits Neovim even while the explorer is open. Git marks refresh when Neovim gets
focus back, when you leave a terminal, and when agentdiff reports agent changes. Nothing
runs `git status` while you switch buffers or idle.

`nvim --headless -u NONE -l tests/explorer.lua` tests the hide lists, opening, the global
keys, folder colours and quitting.

## Editing behaviour

- **Folding** is Neovim's own: LSP folding ranges when the server provides them, otherwise
  Tree-sitter, otherwise indentation (`lua/config/folds.lua`). Files open unfolded;
  `zR`/`zM`/`zr`/`zm`/`za` are the built-in commands and `zU` closes the child folds of the
  fold under the cursor. `nvim --headless -u NONE -l tests/folds.lua` tests it.
- **Gutter** (`lua/config/statuscolumn.lua`): every kind of sign has its own column, so none
  hides another: `[breakpoint][diagnostic][lightbulb] number [git][fold]`. Errors from several
  sources (basedpyright and mypy) show as one icon, the most severe; signs from other plugins
  share the breakpoint column. `nvim --headless -u NONE -l tests/statuscolumn.lua` tests it.
- **Breadcrumbs** (`Class › Method` of the cursor) sit in the statusline next to the file
  name for buffers with a document-symbol server, updated when the cursor rests
  (`lua/plugins/breadcrumbs.lua`; `<leader>ub` toggles).
- **Linters** (nvim-lint) run when a buffer opens and when it's saved, and on entering it or
  leaving insert mode only if its text changed since the last lint. They never run while
  you type, and an `<Esc>` without edits doesn't restart a slow linter such as mypy.
  `<leader>ud` only changes whether diagnostics refresh while typing.
  `nvim --headless -u NONE -l tests/lint.lua` tests the triggers.
  Linter diagnostics sent back to LSP servers (e.g. in the lightbulb's code-action
  requests) are completed with their range and message first, since nvim-lint stores only
  a partial LSP diagnostic and strict servers like ruff reject it
  (`lua/plugins/lsp-diagnostic-fix.lua`, `tests/lsp-diagnostic-fix.lua`).
- **Display toggles** are remembered across restarts in `stdpath("state")/prefs.json`: rainbow
  brackets `<leader>ur`, breadcrumbs `<leader>ub`, the code-action lightbulb `<leader>ul`,
  inlay hints `<leader>li`, code lenses `<leader>lct` (`tests/toggles.lua`).
- `]t`/`[t` jump between TODO comments; the next/previous test is `<leader>tnn`/`<leader>tnp`
  (failed tests: `]T`/`[T`).

## Resolving conflicts

During a merge, rebase, cherry-pick, revert or a conflicting `git stash pop`, every
conflict names its two sides by **role**, with the real branch or commit:

| Operation | YOURS | INCOMING |
|---|---|---|
| merge | the branch you're on | the branch being merged in |
| rebase | your commit being replayed | the branch you're rebasing onto |
| cherry-pick | the branch you're on | the picked commit |
| revert | the branch you're on | the revert |
| stash pop/apply | your working tree | the stashed changes |

Git's own words "ours"/"theirs" swap during a rebase (there "ours" is the other branch);
nothing here uses them. `<leader>gC?` shows how they map for the current operation.

- **In the file:** both sides are highlighted, and the marker lines say
  `▼ YOURS · feature (your commit a1b2c3 "fix login")` and `▼ INCOMING · main (rebasing onto)`.
  `<leader>gCo` keeps yours, `<leader>gCt` takes incoming, `<leader>gCb`/`<leader>gCB` keep
  both, `<leader>gC0` neither; `]x`/`[x` move between conflicts. which-key shows each key
  with the branch it keeps. Diagnostics are hidden while the file has markers.
- **Resolve view** (`<leader>gCr`): YOURS and INCOMING side by side, and below them the
  RESULT, a live preview of the file around the conflict. `o`/`t`/`b`/`B`/`x` choose whole
  sides; `<Space>` keeps or drops a single line (or a visual selection) to mix both sides;
  `J`/`K` reorder the kept lines; `e` edits the result by hand; `<CR>` writes it and moves
  to the next conflict; `n`/`p` skip without writing; `u` undoes the last write; `q` closes.
- **Conflict center** (`<leader>gCC`): what's happening ("REBASING feature onto main,
  commit 2 of 5"), which side is which, and each conflicted file with its count. `<CR>`
  resolves a file, `m` opens diffview's 3-way view (labelled by role too), `s` stages, `c`
  continues, `S` skips a rebase commit, `A` aborts.
- **Next steps:** once a file has no markers left you're told to save it and stage it
  (`<leader>gCa`, refused while markers remain); once nothing is conflicted, `<leader>gCc`
  continues with git's default message (refused while files are unresolved).
  `<leader>gCA` aborts after asking. The statusline shows `⚔ REBASE 2/5 · 3 files` meanwhile.

Nothing runs while no operation is in progress: detection only checks git's state files
(`MERGE_HEAD`, `rebase-merge/`, …) on focus, directory change and terminal leave.
`nvim --headless -u NONE -l tests/conflicts.lua` tests all of it against real repositories.

## Workspace persistence (plugin-free)

Per project (cwd): auto-session saves the session automatically on exit and restores it
automatically when Neovim starts with no file arguments (buffers, layout, and bufferline
pins — pins ride in the session via the `globals` sessionoption plus a post-restore
re-sync). The explorer's expanded folders and open/closed state persist beside the session
and are reapplied on restore (also after `:restart`). DAP breakpoints (line/condition/log) persist separately to
`stdpath('state')` via the workspace package and reappear per file on open, session or not.

Buffers, pins, breakpoints, and explorer state also save at mutation time (debounced),
so they survive `:restart` without relying on exit hooks. They live in
`stdpath('state')/workspaces/<cwd-key>.json` (buffers, pins, breakpoints) and
`stdpath('state')/explorer/<cwd-key>.json` (explorer; files saved by the old neo-tree setup
under `neotree/` are read once); scope.nvim's per-tab buffer lists ride
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
an inactive one.

New worktrees default to `<main-checkout>.worktrees/<branch>` (for `/work/client/backend`
and `feature/login`: `/work/client/backend.worktrees/feature/login`), with an editable
destination. Creation never fetches or copies `.env` files and dependencies; set those up
per checkout.

A switch saves the outgoing session and this configuration's workspace state (the
`config.workspace` participant: buffers, pins, breakpoints, explorer, scope), then
restores the target's. Unsaved buffers must all be saved or the switch is cancelled (the
default); live Neovim terminal jobs and debug sessions block it. External terminals, tmux,
servers and AI agents keep their working directories. A broken target session puts you
back in the source; see the plugin's README for every safeguard and the recovery rules.
The enabled integrations are auto-session, nvim-dap, scope, bufferline and snacks_explorer.

`nvim --headless -u NONE -l tests/workspace.lua` runs the end-to-end suite against the
installed plugins (`NVIM_WORKSPACE_TEST_GIT_WORKTREE=~/Github/git-worktree.nvim` tests a
local checkout instead).

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

To try unpublished edits, start Neovim with `NVIM_DEV_PLUGINS=1`: every one of these with a
checkout in `~/Github/<name>` is loaded from that checkout instead of the installed copy
(`NVIM_DEV_PLUGINS=agentdiff.nvim,vale.nvim` limits it to those). The installed copy leaves
`runtimepath`, so each plugin's `plugin/` files run once.

## Measuring a session

`NVIM_PROFILE=1 nvim` turns on the session profiler (`lua/config/profile.lua`). Without the variable nothing is installed. While it runs it records:

- Lua autocmd callbacks by event and augroup (runs, total, slowest);
- LSP requests by client and method (count, cancelled, response time);
- processes the editor starts, by executable (count, runtime);
- sampled Lua time by plugin or configuration module (this also covers decoration providers and timers).

| Command | What it does |
|---|---|
| `:ProfileReport` | Shows the numbers in a new tab (`q` closes it) and saves a JSON snapshot in `stdpath("state")/profile/` |
| `:ProfileReset` | Clears every counter, for measuring one activity from a clean start |
| `:ProfileCompare` | Pick two snapshots, from the state folder or the committed `docs/profiles/`; each row is shown per hour of uptime, with the difference |

`nvim --headless -u NONE -l tests/profile.lua` tests the profiler itself.

## Plugin updates

`<leader>pu` (or `:lua vim.pack.update()`) → review buffer → `:write` to apply, `:quit`
to discard. `nvim-pack-lock.json` is committed; treat it like a lockfile.

## Key bindings (leader = space)

| Prefix | Group |
|---|---|
| `<leader>f` | find: files `<leader><leader>`, resume `ff`, grep `fg`, word under cursor `fw`, buffers `fb`, help `fh`, recent `fr`, diagnostics `fd`, keymaps `fk`, workspace symbols `fs`, TODOs `ft`, notifications `fn` |
| `<leader>g` | git: lazygit `gg`, stage hunk `gs`, reset `gr`, preview `gv`, blame `gb`, draft commit msg (in gitcommit) `gm`, commit msg chat (in gitcommit) `gc`, configure commit AI (in gitcommit) `gM` |
| `<leader>gC` | conflicts (by role, never ours/theirs): center `gCC`, resolve view `gCr`, 3-way view `gCm`, stage file `gCa`, continue `gCc`, abort `gCA`, explain `gC?`; in a conflicted file keep yours `gCo`, take incoming `gCt`, both `gCb` / incoming first `gCB`, neither `gC0`, next/previous `gCn`/`gCp` or `]x`/`[x`, list `gCQ` (quickfix) / `gCq` (Trouble) |
| `<leader>gw` | worktrees: switch workspace `gww`, create and switch `gwc`, delete inactive checkout `gwd` |
| `<leader>d` | debug: continue `dc`/`F5`, breakpoint `dd`/`B`, groups: breakpoints `db*`, step `ds*` (+`F9/F10/F11`), windows `dw*`, UI `du*` (toggle `duu`), REPL `dr*` (clear `drx`, highlighted), sessions `dS*`, launch `dl*`, eval `de/dE`, hover `dh`, virtual text toggle `dv` (persisted) |
| `<leader>c` | code: format `cf`, diagnostics float `cd`, inlay hints `ci` (LSP: `gd`, `grr`, `grn`, `gra`, `K`) |
| `<leader>b` | buffers: pin `bp`, close others `bo`, delete `bd`/`xw`, close all `xa` / others `xA` (keep pinned+unsaved; cycle: `Tab`/`S-Tab`, `S-h`/`S-l`) |
| `<leader>o` | tasks: run `or`, list `ot` (.vscode/tasks.json supported) |
| `<leader>k` | trouble: diagnostics `kd`/`kD`, loclist `kl`, quickfix `kq`, LSP panel `kw`, symbols `ks` |
| `<leader>l` | lsp: code action `la`, references + implementations `lf`, rename `lr`, signature `lk`, outline `lo`, diagnostics `ld*`, workspace `lw*`, calls `lh*`, inlay hints `li` (persisted, default off), codelens run `lcr`/refresh `lcR`/toggle `lct` (persisted, default on) |
| `<leader>x` | close: buffer `xw`, all `xa`, others `xA` (keep pinned/unsaved) |
| `<leader>u` | ui: theme `ut`, dismiss notifications `un`, undotree `uu`, AI toggle `ua`; persisted toggles: rainbow `ur`, breadcrumbs `ub`, lightbulb `ul`, format-on-save `uf`, live diagnostics display `ud` (default: updates after insert mode) |
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
