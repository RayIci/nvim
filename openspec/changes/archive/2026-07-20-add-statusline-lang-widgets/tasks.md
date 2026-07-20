## 1. Global statusline indicators (lualine)

- [x] 1.1 In `lua/plugins/lualine.lua`, add a `formatters` component function reading `require("conform").list_formatters(0)` (guard when conform not loaded), returning an icon-prefixed comma list (`󰉼 …`), empty when none.
- [x] 1.2 Add a `linters` component function reading `require("lint").linters_by_ft[vim.bo.filetype]` (guard when lint not loaded), returning `󰁨 …`, empty when none.
- [x] 1.3 Place the formatter and linter components in `lualine_x` next to the existing LSP-clients component, each with its own color (LSP blue, formatters green, linters purple) matching the old config.

## 2. Pack statusline capability (framework + lualine bridge)

- [x] 2.1 In `lua/langs/init.lua`, add `statusline?` to the `LangPack` type (list of `{ render, cond?, icon?, color? }`) and `statusline` to `LangMerged`; initialize it in `M.merged`.
- [x] 2.2 In `collect()`, append each pack's `statusline` entries into `merged.statusline`.
- [x] 2.3 In `M.setup()`, call `require("plugins.lualine").apply(merged.statusline)` alongside the other subsystem `apply()` calls.
- [x] 2.4 In `lua/plugins/lualine.lua`, add a module-local widgets table and an `M.apply(widgets)` that stores them; add a bridge component in `lualine_x` that, at render time, iterates the stored widgets, skips those whose `cond` returns false, and concatenates non-empty `render()` outputs (prefixing each `icon`).

## 3. Python venv widget

- [x] 3.1 In `lua/langs/python.lua`, add a `python_venv` render function: `require("venv-selector").venv()` under `pcall`, return `""` when absent/empty, else the basename.
- [x] 3.2 Declare `statusline = { { render = python_venv, cond = ft == "python", icon = "🐍" } }` on the pack so it flows through the bridge.

## 4. Verify

- [x] 4.1 Launch nvim on a non-Python buffer: confirm no venv widget, and LSP/formatter/linter indicators reflect that buffer (or hide when empty).
- [x] 4.2 Open a Python file, select a venv via `<leader>-pp` (VenvSelect): confirm `🐍 <name>` appears; deselect / open a non-Python buffer: confirm it disappears.
- [x] 4.3 Confirm a pack with no `statusline` field still loads (bridge renders empty), and run `openspec validate add-statusline-lang-widgets --strict`.
