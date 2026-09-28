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

- [x] 3.1 List every highlight group each installed UI plugin defines (grep plugin sources under `vim.pack` install dir for `nvim_set_hl` / `highlight default` / group tables) and record the checklist in a comment at the top of `lua/vale/integrations/init.lua`; verify the list covers every plugin named in the vale-colorscheme spec
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

## 6. Lab core

- [x] 6.1 `lab/contrast.lua`: WCAG 2.x relative luminance and contrast ratio; verify `#000000` vs `#FFFFFF` = 21.0 and `#777777` vs `#FFFFFF` ≈ 4.48
- [x] 6.2 `lab/candidates.lua`: ordered slot list per design D5 (`slot`, `label`, `on`, `candidates`), candidate 1 injected from the reference at runtime; verify every slot key exists in both palettes
- [x] 6.3 `lab/writer.lua`: single-line hex replacement per design D6, refusing on 0 or >1 matches and on a modified open palette buffer; verify by locking a value and checking `git diff` shows exactly one changed line
- [x] 6.4 `lab/init.lua` + `lab/panel.lua`: `:ValeLab [night|day]` tab with 2×3 sample grid, `<Tab>` paging, side panel with swatches/hex/contrast/low-contrast marker/"VS Code" label on candidate 1, palette strip (locked/pending), buffer-local `]c` `[c` `]s` `[s` `<CR>` `v` `q` `Q`, LSP-attached indicator per sample in the panel; verify each spec scenario in vale-lab by hand
- [x] 6.5 Hot reload: `BufWritePost` on palettes, `semantics.lua`, `groups/*`, `integrations/*` and the candidates file reloads the active variant (clearing vale module cache) while the lab is open; `TabClosed` restores the previous colorscheme; verify by editing a hex in the night palette and saving, and by closing the lab after opening it from tokyonight-night
- [x] 6.6 Measure `:colorscheme vale-night` load time (`vim.uv.hrtime` around `load`); verify it is under 20 ms, else add per-mtime caching (design risk)

## 7. Picking rounds — vale-night (interactive with the user)

- [ ] 7.1 Foundation: bg, fg, chrome, float, line, surface, border, overlay (settle base shade count); locked in night palette
- [ ] 7.2 Quiet: comment, line numbers, punctuation, muted text; locked
- [ ] 7.3 Loud: storage keyword, control keyword (decide one vs two keyword colours), function, string, type, constant, number, variable/property/parameter (decide coloured variables vs fg), decorator, namespace, builtin; locked and `semantics.lua` updated
- [ ] 7.4 Signals: diagnostics ×4, git add/change/delete, diff backgrounds (check in diffview); locked
- [ ] 7.5 UI: selection, search/cursearch, cursorline, float bg/border, pmenu/sel, bracket colours for rainbow-delimiters (decide VS Code bracket-pair colours); locked
- [ ] 7.6 ANSI 16: confirm mapping and brights in a toggleterm running `ls --color`, `git log --graph --color`, and a 16-colour test script; locked

## 8. Picking rounds — vale-day (interactive with the user)

- [ ] 8.1 Repeat 7.1–7.6 for the day palette starting from night's hue decisions, with contrast checked against the light background; locked

## 9. Final validation

- [ ] 9.1 Run `openspec validate add-vale-colorscheme --strict`; walk through every scenario in the three spec deltas on both variants; run `:checkhealth` for errors introduced by this change
