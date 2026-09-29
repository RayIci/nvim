# Tasks

## 1. Reference and palette foundation

- [x] 1.1 Fetch VS Code's `dark_modern.json`, `dark_plus.json`, `dark_vs.json`, `light_modern.json`, `light_plus.json`, `light_vs.json` from `microsoft/vscode` (`extensions/theme-defaults/themes/`) and write `lua/vale/reference/vscode_modern.lua` (pure data, `dark`/`light` tables, source file + scope/key comment per value); verify every value quoted in the explore session is either confirmed or corrected in the file
- [x] 1.2 Write `lua/vale/palettes/night.lua` and `day.lua` seeded from the reference (blocks `base`, `accent`, `ansi`, `ui`; one `key = "#rrggbb", -- role` per line; header comment stating the format rule); verify with `lua -e 'dofile("lua/vale/palettes/night.lua")'` (plain Lua, no nvim) and a key-set comparison script showing identical keys and that every `ansi`/`ui` name resolves
- [x] 1.3 Write `lua/vale/semantics.lua` mapping roles to palette names, mirroring VS Code scopes (storage keyword → blue, control keyword → purple, function → yellow, string → orange, type → teal, variable/parameter/property → light_blue, constant/enum → cyan, number → sage, comment → green, regex → red, escape → gold, diagnostics, git, diff); verify every role resolves to a hex for both palettes

## 2. Colorscheme core

- [x] 2.1 Implement `lua/vale/init.lua` `load(variant, overrides)` (hi clear, background, colors_name, `dofile` palette, overrides, resolve names, merge group modules, `nvim_set_hl`, `terminal_color_0..15`) and `colors/vale-night.lua` / `colors/vale-day.lua`; verify `:colorscheme vale-night` sets `vim.g.colors_name`, `vim.o.background` and `Normal` as specified, and `:echo g:terminal_color_4` matches `ansi[5]` (slot 4)
- [x] 2.2 Implement `groups/editor.lua` covering `:h highlight-groups` (Normal/NC/Float, FloatBorder/Title, CursorLine/Column, LineNr/CursorLineNr, SignColumn, StatusLine/NC, TabLine*, WinSeparator, Pmenu*, Visual, Search/IncSearch/CurSearch, MatchParen, Folded, NonText/Whitespace, Diff*, Spell*, messages, QuickFixLine, WinBar); verify `:hi` shows no editor group falling back to Neovim defaults after `hi clear`
- [x] 2.3 Implement `groups/syntax.lua` (standard Vim groups) and `groups/treesitter.lua` (Neovim 0.12 capture list incl. `@keyword.return/conditional/repeat/import/exception`, `@variable.parameter/member/builtin`, `@function.method/builtin`, `@type.builtin`, `@constant.builtin`, `@string.escape/regex`, `@comment.documentation/todo/error/warning/note`, `@attribute`, `@module`, `@punctuation.*`, `@markup.*`, `@diff.*`, `@tag*`); verify with `:Inspect` on each token kind in a Python and a TypeScript buffer
- [x] 2.4 Implement `groups/lsp.lua` (`@lsp.type.*`, `@lsp.mod.*`, `@lsp.typemod.*` linked to treesitter equivalents, LspReference*, LspInlayHint, LspCodeLens, LspSignatureActiveParameter) and `groups/diagnostics.lua` (base, VirtualText, Underline, Sign, Floating, Ok, Deprecated, Unnecessary); verify in a C# file with roslyn attached that `:Inspect` on a class, method, parameter and property shows the same colours as before attach, and that four severities render distinctly

## 3. Plugin integrations

- [x] 3.1 List every highlight group each installed UI plugin defines (grep plugin sources under `vim.pack` install dir for `nvim_set_hl` / `highlight default` / group tables) and record the checklist in a comment at the top of `lua/vale/integrations/init.lua`; verify the list covers every plugin named in the vale-engine spec
- [x] 3.2 Git integrations: gitsigns, diffview, neogit, git-conflict, octo; verify by opening a diffview and neogit status on a modified repo and checking add/delete/change/text regions are distinct and readable, and that the octo `ColorScheme` workaround still colours an Octo PR buffer
- [x] 3.3 Picker/navigation: telescope, flash, illuminate, grug-far, window-picker; verify visually in each
- [x] 3.4 Shell UI: neo-tree, bufferline, barbecue/navic, which-key, noice, snacks, trouble, todo-comments, indent-blankline, rainbow-delimiters, toggleterm, nvim-ufo, render-markdown, mason; verify visually in each
- [x] 3.5 Code/debug/AI: blink.cmp (incl. kind icons), lspsaga, lightbulb, nvim-dap signs, dap-ui, dap-virtual-text, neotest, overseer, multicursor, sidekick; verify visually in each
- [x] 3.6 Lualine theme `lua/vale/lualine.lua` plus `lua/lualine/themes/vale-night.lua` / `vale-day.lua` shims; verify `theme = "auto"` picks them up (mode colours change per mode) on both variants

## 4. Existing config integration

- [x] 4.1 `lua/plugins/theme.lua`: prepend Vale Night / Vale Day (light) entries and change the first-launch fallback to `vale-night`; verify in the Themery picker (vale first, live preview works) and by starting with the themery state file moved away
- [x] 4.2 `lua/plugins/lualine.lua`: recording/LSP/formatter/linter label colours read from the active theme's `DiagnosticError`/`DiagnosticInfo`/`DiagnosticOk`/`Statement` fg (old hex as fallback), no vale reference; verify across vale and third-party themes without restart
- [x] 4.3 `lua/plugins/neotree.lua`: folder icon links to the theme's `FolderIcon` group when defined (vale defines it), else `#E5C07B`; `lua/plugins/octo.lua`: octo palette re-read from standard groups on ColorScheme; verify by switching themes

## 5. Lab samples

- [x] 5.1 Write the shared token checklist as a header comment in `lua/vale/lab/samples/README.md`, then samples for Python, TypeScript, Lua, Kotlin, SQL, Bash, JSON, YAML, Markdown and Dockerfile, each covering every checklist item the language supports; verify with `:Inspect` that each checklist token in each sample has a distinct capture
- [x] 5.2 C# sample with minimal `Sample.csproj`, Java sample with minimal `pom.xml`, Rust sample with minimal `Cargo.toml`; verify roslyn, jdtls and rust-analyzer attach (`:checkhealth vim.lsp` / `:LspInfo`) and semantic tokens are applied (`:Inspect` shows `@lsp.*`)

## 6. Migrate to the theme layout

- [x] 6.1 Move `lua/vale/palettes/{night,day}.lua` to `themes/vale/`, move the day `folder = "amber"` override into `themes/vale/semantics.lua`, and switch the engine to `load(name, variant, overrides)` with layered semantics (D3, D4); regenerate `colors/vale-*.lua` and `lua/lualine/themes/vale-*.lua` in the `(name, variant)` form; verify both colorschemes load with identical groups to before (group-by-group comparison) and the plugin-override check still reports 0
- [x] 6.2 Add `lua/vale/template.lua` (every palette key with its role comment) and `lua/vale/slots.lua` (group, label, `on`, text flag per slot, from the old candidates list without candidates); verify every palette key has exactly one template line and one slot entry
- [x] 6.3 Move samples to `lua/vale/samples/` and the writer to `lua/vale/studio/writer.lua`; remove `lua/vale/lab/` (init, panel, candidates, contrast) and `:ValeLab`/`<leader>uv`; verify startup has no new errors and `grep -r ValeLab lua/` is empty
- [x] 6.4 `lua/plugins/theme.lua`: prepend one Themery entry per `colors/*.lua` file in the config instead of the hard-coded vale entries (D12); verify vale-night/day still appear first and a dummy `colors/test-night.lua` appears after restart (then remove it)

## 7. Studio core

- [x] 7.1 `studio/server.lua`: HTTP/1.1 over `vim.uv` on `127.0.0.1:0` (request line, headers, Content-Length bodies, 400/413 on malformed/oversized), static assets, JSON responses, SSE stream with keep-alive; verify with `curl` (asset served, bad request → 400)
- [x] 7.2 Access control (D7): token in URL and `X-Vale-Token`, Host and Origin checks; verify with `curl`: no token → 403, wrong Host → 403, foreign Origin on POST → 403, correct request → 200
- [x] 7.3 `studio/init.lua`: `:Vale`, `:Vale new <name>`, `:Vale edit <name>`, `:Vale stop` with completion; open via `vim.ui.open` and print the URL; one server per instance; stop on `:Vale stop`, `VimLeavePre`, and 30 s without an SSE client (D11); verify each path headless
- [x] 7.4 `studio/generate.lua` + `POST /api/create` (D5): name validation, dark/light/both, from VS Code (template + reference) or copy of a theme, shims written; verify creating `test` from VS Code yields palettes equal in keys and values to the reference, `:colorscheme test-night` loads, taken/invalid names are refused, then remove `test`
- [x] 7.5 `studio/render.lua` + `POST /api/preview` (D8): apply overrides live in Neovim and return coloured spans per sample; verify a keyword span's fg equals the overridden `accent.blue` and that Neovim's `@keyword` group shows the same value
- [x] 7.6 `POST /api/save` and discard (D10, D11): multi-slot all-or-nothing palette writes, `semantics.lua` regeneration, refusal on modified buffers, discard restores the previous colorscheme; verify `git diff` shows only changed lines and discard leaves files untouched
- [x] 7.7 Hot reload (D13): watcher on the edited theme directory reloads the theme and pushes `changed`; verify by editing a palette file externally while a session is open

## 8. Studio page

- [x] 8.1 `assets/index.html` + `style.css` + `app.js`: theme list and new-theme form (name, variants, starting point) calling the API; verify in the browser that creating a theme opens its editor
- [x] 8.2 Editor: all slots grouped, night/day toggle, hex input with validation, colour picker, reset, contrast with low-contrast mark, OKLCH variations row, unsaved markers, Save/Discard; verify each `vale-studio` editor scenario by hand
- [x] 8.3 Roles section: a selector per semantic role (palette names + plain text), changed-from-default markers; verify remapping strings to `green` recolours the page preview and Neovim
- [x] 8.4 Preview pane: a tab per sample rendering spans with Neovim's colours, line numbers and background; debounced preview requests while dragging; verify the page preview matches Neovim for the Python and C# samples

## 9. Tune vale in the studio (interactive with the user)

- [ ] 9.1 vale-night: foundation, syntax, signals, UI and ANSI tuned in the studio (including the open choices: one vs two keyword colours, coloured vs plain variables, bracket colours); saved
- [ ] 9.2 vale-day: tuned the same way starting from night's hue decisions, with contrast checked against the light background; saved

## 10. Final validation

- [ ] 10.1 Run `openspec validate add-vale-colorscheme --strict`; walk through every scenario in the four spec deltas; run the plugin-override check on every theme; confirm no new startup errors
