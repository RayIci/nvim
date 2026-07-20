## 1. Fix jsonc treesitter warning

- [x] 1.1 In `lua/langs/json.lua`, remove `"jsonc"` from the `treesitter` list (keep `json`, `json5`).
- [x] 1.2 Register the `json` parser for the `jsonc` filetype (e.g. `vim.treesitter.language.register("json", "jsonc")`) so jsonc still highlights; place it where the pack is loaded (pack `setup` or a small FileType/register call).
- [x] 1.3 Verify: launch nvim, confirm no `skipping unsupported language: jsonc` warning; open a `.jsonc` file and confirm treesitter highlighting is active (`:InspectTree`).

## 2. Fix roslyn mason package name

- [x] 2.1 In `lua/langs/dotnet.lua`, change the mason entry `"roslyn"` to `"roslyn-language-server"` (leave the `lsp = { roslyn = {} }` key and roslyn.nvim untouched).
- [x] 2.2 Verify: launch nvim, confirm the `Cannot find package "roslyn"` error is gone; run `:Mason` and confirm `roslyn-language-server` installs; open a `.cs` file and confirm the roslyn LSP attaches.

## 3. Port environment-aware clipboard

- [x] 3.1 Create `lua/config/clipboard.lua` porting the old provider-selection logic (WSL→win32yank/WSLg/X11/clip.exe, Wayland, X11, macOS, OSC52), the `vim.g.clipboard` guard, `clipboard = unnamedplus`, and the startup `vim.notify` status message.
- [x] 3.2 Wire it into startup (require it from `init.lua` or `lua/config/`), and remove the now-redundant scheduled `o.clipboard = "unnamedplus"` block in `lua/config/options.lua`.
- [x] 3.3 Verify on this WSL box: startup notification reads `WSL [win32yank]`; yank in nvim and paste into a Windows app; paste from Windows into nvim.

## 4. Add winbar breadcrumbs (barbecue + navic)

- [x] 4.1 Add `utilyre/barbecue.nvim` and `SmiteshP/nvim-navic` to `lua/config/pack.lua` (web-devicons already present).
- [x] 4.2 Create `lua/plugins/barbecue.lua` with `M.setup()` calling `barbecue.setup()` with `attach_navic = true` and `exclude_filetypes` covering neo-tree, toggleterm/terminal, Trouble, and other non-code panels.
- [x] 4.3 Register `require("plugins.barbecue").setup()` in `lua/plugins/init.lua` (UI group).
- [x] 4.4 Verify: breadcrumb shows the symbol path in a code buffer and updates on cursor move; confirm it does NOT appear in neo-tree, a terminal, or other plugin windows.

## 5. Replace vim-visual-multi with multicursor.nvim

- [x] 5.1 In `lua/config/pack.lua`, replace `mg979/vim-visual-multi` with `{ src = gh("jake-stewart/multicursor.nvim"), version = "1.0" }` (branch/version 1.0).
- [x] 5.2 Rewrite `lua/plugins/visual-multi.lua` (or add a new module) to `require("multicursor-nvim").setup()` and bind the old keymaps: `<C-n>`/`<C-p>` add match, `q` skip (via `addKeymapLayer`), `<C-Up>`/`<C-Down>` line cursors, `<C-Left>`/`<C-Right>` rotate, `<leader>ma` all matches, visual `<leader>ms/mS/mi/mA`, `<leader>mx` delete cursor, `<Esc>` clear/re-enable, plus the `MultiCursor*` highlight links.
- [x] 5.3 Remove any stale vim-visual-multi globals (`vim.g.VM_*`) from the old module.
- [x] 5.4 Verify: `<C-n>` adds next match, `q` skips, edits apply to all cursors live, `<Esc>` clears.

## 6. Wrap up

- [x] 6.1 Run `openspec validate fix-jsonc-roslyn-clipboard-breadcrumbs --strict` and fix any issues.
- [x] 6.2 Full nvim restart with a clean session: confirm no startup warnings/errors from any of the five items.
