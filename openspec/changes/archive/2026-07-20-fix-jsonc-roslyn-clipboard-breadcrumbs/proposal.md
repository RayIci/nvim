## Why

Two startup diagnostics are firing on every launch, and two behaviors from the
previous config never got ported:

- **jsonc warning** — `[nvim-treesitter] warning: skipping unsupported language: jsonc`.
  The `json` language pack requests a `jsonc` parser that no longer exists on
  nvim-treesitter's `main` branch (only `json`, `json5`, `jsonnet` ship).
- **roslyn error** — `mason-tool-installer` errors with `Cannot find package "roslyn"`.
  The mason registry renamed the package to `roslyn-language-server`; the dotnet
  pack still asks for the old name, so C# tooling never installs.
- **Clipboard** — the old config selected a clipboard provider per environment
  (WSL → `win32yank.exe`, then Wayland/X11/OSC52 fallbacks). The current config
  only sets `clipboard = unnamedplus` and relies on Neovim's autodetection.
- **Breadcrumbs** — the old config showed a VSCode-style winbar breadcrumb of the
  symbol path at the cursor (barbecue.nvim + nvim-navic). It was never ported.
- **Multi-cursor** — the current config regressed to `vim-visual-multi` (Ctrl-n),
  but the old config used the modern pure-Lua `jake-stewart/multicursor.nvim`
  with `q` to skip a match, `<C-p>` for the previous match, cursor rotation, and
  a set of `<leader>m` visual helpers.

## What Changes

- Remove `jsonc` from the JSON pack's treesitter list and register the `json`
  parser to serve the `jsonc` filetype, so jsonc files keep highlighting with no
  warning.
- Rename the dotnet pack's mason entry `roslyn` → `roslyn-language-server`
  (the LSP-server identifier `roslyn` used by roslyn.nvim is unchanged).
- Port the multi-environment clipboard provider selection as a config module,
  keeping the informational startup notification.
- Add barbecue.nvim + nvim-navic winbar breadcrumbs, shown only on real code
  windows (excluded from neo-tree, terminals, and other plugin panels).
- Replace `vim-visual-multi` with `jake-stewart/multicursor.nvim`, porting the
  old keymaps (`<C-n>`/`<C-p>` add match, `q` skip, `<C-Up>`/`<C-Down>` line
  cursors, `<C-Left>`/`<C-Right>` rotate, `<leader>m*` visual helpers, `<Esc>`
  clear/re-enable).

## Capabilities

### New Capabilities
- `system-clipboard`: Environment-aware clipboard provider selection (WSL,
  Wayland, X11, macOS, SSH/OSC52) with a startup status notification.

### Modified Capabilities
- `language-packs`: JSON pack no longer requests a nonexistent `jsonc` parser
  yet still highlights jsonc; dotnet pack installs the correctly-named
  `roslyn-language-server` mason package.
- `ui-shell`: Adds a winbar breadcrumb of the cursor's symbol path, scoped to
  code windows only.
- `editing-experience`: Multi-cursor editing is provided by multicursor.nvim
  instead of vim-visual-multi, preserving the `<C-n>`/`q` UX.

## Impact

- `lua/langs/json.lua` — treesitter list + jsonc filetype registration.
- `lua/langs/dotnet.lua` — mason package name.
- `lua/config/clipboard.lua` (new) + `init.lua`/`lua/config/options.lua` wiring.
- `lua/plugins/barbecue.lua` (new), `lua/config/pack.lua` (add barbecue +
  nvim-navic), `lua/plugins/init.lua` (register setup).
- `lua/plugins/visual-multi.lua` — replaced by multicursor.nvim setup + keymaps.
- Dependencies added: `utilyre/barbecue.nvim`, `SmiteshP/nvim-navic`,
  `jake-stewart/multicursor.nvim`. Removed: `mg979/vim-visual-multi`.
