# Design

## Context

See proposal.md for motivation and the specs for requirements. Relevant current state:

- Plugins are loaded with native `vim.pack` (`lua/config/pack.lua`) and set up explicitly in `lua/plugins/init.lua`; there is no lazy-loading. The config directory is on `runtimepath`, so a top-level `colors/` directory is picked up by `:colorscheme`.
- Themery (`lua/plugins/theme.lua`) applies the persisted theme during `setup()` and falls back to `catppuccin-mocha`. `livePreview = true` means `:colorscheme` runs on every cursor move in the picker, so a load must be fast and must not leave state behind.
- Theme-sensitive code outside themes: `lua/plugins/lualine.lua:133-136` (four hardcoded tokyonight hex values), `lua/plugins/neotree.lua` (`FOLDER_ICON_COLOR`, reasserted on `ColorScheme`), `lua/plugins/octo.lua` (rebuilds `Octo*` groups on `ColorScheme`, which stays as is).
- In-tree plugin precedent: `lua/commitsmith/` (a module tree plus a thin `lua/plugins/commitsmith.lua` setup file).

## Goals / Non-Goals

**Goals:**
- A palette file that someone who has never seen Neovim Lua can read and copy into a ghostty/kitty/tmux config.
- A single place to change the meaning of a colour (semantics), separate from the colour itself (palette).
- A picking loop that is quick: preview in milliseconds, lock with one key, and new candidates arrive by saving a file.

**Non-Goals:**
- Generating terminal, tmux or prompt themes (a later change; the palette shape is what matters now).
- Colour-space tooling (OKLCH generation, colour-blind simulation). Candidates are written by hand in the picking sessions.
- User-facing configuration options (`setup({ transparent = … })`, style toggles). This is a personal theme; edit the files.
- Compilation or caching of highlights.

## Decisions

### D1. Module layout

```
colors/
  vale-night.lua            require("vale").load("night")
  vale-day.lua              require("vale").load("day")
lua/vale/
  init.lua                  load(variant, overrides?): hi clear, set bg/colors_name,
                            build groups, apply, set terminal colours
  palettes/
    night.lua               pure data (portable contract)
    day.lua                 pure data, same keys
  reference/
    vscode_modern.lua       pure data: dark/light VS Code values per slot, source file per value
  semantics.lua             function(palette) -> roles table (role -> hex)
  groups/
    editor.lua  syntax.lua  treesitter.lua  lsp.lua  diagnostics.lua
  integrations/
    gitsigns.lua telescope.lua neotree.lua …   one file per plugin
  lualine.lua               lualine theme table built from roles
  lab/
    init.lua  panel.lua  candidates.lua  contrast.lua  writer.lua
    samples/  sample.py  sample.ts  … csharp/Sample.cs + Sample.csproj
                                     java/Sample.java + pom.xml
lua/lualine/themes/vale-night.lua, vale-day.lua   thin shims so `theme = "auto"` finds them
```

Each `groups/*` and `integrations/*` module is `function(r) return { Group = spec, … } end`, taking the roles table `r`. `init.lua` merges them and calls `nvim_set_hl` once per group.

*Alternative:* one big highlights file (as in many small themes). Rejected, because plugin coverage is the point of this change and a per-plugin file makes it auditable: one file per installed plugin, easy to spot what's missing.

### D2. Palette format: Lua pure data, names inside `ansi`/`ui`

VS Code colours with alpha (selection highlight, find match, diff backgrounds, hint, whitespace) are pre-blended against the variant's editor background when seeding, since Neovim has no alpha. The reference file records the original RGBA value next to the blended hex.

The palette uses `base` (`crust`, `mantle`, `bg`, `surface`, `overlay`, `muted`, `subtext`, `fg`, and further shades if picking needs them), `accent` (named hues seeded from VS Code: `blue`, `purple`, `yellow`, `orange`, `teal`, `light_blue`, `cyan`, `sage`, `green`, `red`, `gold`), `signal` (`error`, `warn`, `info`, `hint`, `add`, `change`, `delete`), `ansi` (16 named slots `black` … `bright_white`, hex or names), and `ui` (hex or names). There is one entry per line, `key = "#rrggbb", -- role`, which keeps the format grep-able and lets the lab rewrite one line (D6).

*Alternatives:* JSON (no comments, which hurts readability) and TOML (needs a parser). A future export script run with `nvim -l` can emit any format from the Lua file, so Lua stays the only source of truth.

Accent names describe the **hue**, not the role (`purple`, not `control_keyword`). That keeps the palette meaningful for a terminal port, where there are no keywords.

### D3. Semantics maps roles to palette names

`semantics.lua` is data: it maps each role to a palette name (`"blue"`, or `"ui.selection"` for a ui entry), with an optional `day` table of per-variant overrides: for example `keyword = "blue"`, `keyword_control = "purple"`, `variable = "light_blue"`, `func = "yellow"`, `string = "orange"`. The initial mapping mirrors VS Code's token scopes. The same mapping serves both variants, because they share keys (a light variant's `yellow` is VS Code's brown `#795E26`: same role, variant-specific hex). A variant can override a role mapping only if picking shows it's needed.

Open design points from exploration (two keyword colours, coloured variables, bracket colours, roles VS Code never coloured) are settled **by editing this file** during picking. The lab hot-reloads it, so they need no separate mechanism.

### D4. Load path and overrides

`load(variant, overrides)` performs these steps:

1. `hi clear`, set `vim.o.background`, `vim.g.colors_name = "vale-" .. variant`.
2. Read the palette with `dofile` (not `require`) so that edits are picked up on reload without clearing `package.loaded`. Apply `overrides` (slot → hex) on top.
3. Resolve names in `ansi`/`ui` to hex, build roles, and merge all group modules.
4. Call `nvim_set_hl` for every group, and set `terminal_color_0..15`.

The lab previews by calling `load(variant, { [slot] = candidate })`. Nothing is written to disk. Group modules are also re-required on reload while the lab is active: their `package.loaded` entries are cleared before the load.

### D5. Lab picking order and slot list

The lab's slot list is an ordered array in `lab/candidates.lua`, following the agreed order: foundation (`bg`, `fg`, `mantle`, `crust`, `surface`, `overlay`), quiet (`muted`/comment, line numbers, punctuation), loud by frequency (keyword, control keyword, function, string, type, constant, number, property/variable, parameter, decorator), signals (diagnostics, git, diff backgrounds), UI (selection, search, cursorline, float, border, pmenu), and ANSI brights. Each entry is `{ slot = "accent.blue", label = "keyword (storage)", on = "base.bg", candidates = { "#…", … } }`. Candidate 1 is injected from the reference palette at runtime, not stored in the file, so it can't drift. The candidates file is plain data that Claude rewrites between rounds in chat. The lab watches it with a `BufWritePost` autocmd (or an fs watcher if edited externally) and re-reads it.

Contrast is calculated with the WCAG 2.x relative-luminance formula against the slot's `on` colour. The threshold is 4.5:1 for text slots; background and border slots show the ratio without a warning.

### D6. Locking rewrites a single line

`writer.lua` reads the palette file and finds the line matching `^%s*<key>%s*=%s*"#%x%x%x%x%x%x"` inside the right block. It replaces only the hex literal and writes the file back. If the pattern matches zero or multiple lines, it refuses and notifies. It never re-serialises the table, which would destroy comments and ordering. If the palette buffer is open and modified, the lock is refused to avoid clobbering unsaved edits.

### D7. Lab layout

The lab opens in a new tab: a 2×3 grid of sample windows, a full-height right-hand panel (scratch buffer; swatches are `████` with a per-hex highlight group recreated after every load, since `hi clear` wipes them) and a two-line palette strip under the grid. `<Tab>` pages through sample sets; the last page includes a terminal printing the 16 ANSI colours, `ls --color` and a coloured `git log` (restarted on ANSI slots, since terminal colours are fixed when a terminal starts). Keys, buffer-local to lab buffers and removed on close: `]c`/`[c` cycle candidates, `]s`/`[s` move between slots, `<CR>` locks, `v` toggles night/day, `q` closes and restores the previous colorscheme, `Q` closes and keeps the vale variant. `TabClosed` also restores (spec: Lab workspace). The LSP-attached indicator per sample is listed in the panel rather than the winbar, because barbecue owns the winbar in code buffers. Locked marks persist in `stdpath("state")/vale-lab.json`. Hot reload uses `fs_event` watchers on the vale directories (debounced), so edits made outside Neovim, such as candidate files written between rounds, are picked up as well as `:write`.

### D8. LSP samples

The C# sample lives in `lab/samples/csharp/` next to a minimal SDK-style `Sample.csproj`, and Java in `lab/samples/java/` with a minimal `pom.xml`, so roslyn/jdtls detect a project root. Other languages rely on treesitter plus whatever server the language pack attaches (lua_ls, basedpyright/pyright, ts, rust-analyzer without Cargo is limited, so add a tiny `Cargo.toml`). The samples are content, not code paths: they only need to exercise the token checklist.

### D9. Integration with existing modules

- **Themery:** prepend `{ name = "Vale Night", colorscheme = "vale-night" }` and `{ name = "Vale Day (light)", colorscheme = "vale-day" }`, and change the fallback to `vale-night`.
- **Rule: config outside vale never references vale.** Wherever the config sets colours itself (so a colorscheme alone cannot reach them), it reads them from standard highlight groups of whatever theme is active.
- **Lualine:** `theme = "auto"` looks up `lualine.themes.<colors_name>`, so vale ships `lua/lualine/themes/vale-night.lua` and `vale-day.lua` (the same way catppuccin/tokyonight ship theirs; optional, since auto would otherwise derive one). The four component colours become draw-time functions returning the fg of `DiagnosticError`, `DiagnosticInfo`, `DiagnosticOk` and `Statement`, with the old hex as fallback.
- **Neo-tree:** the forced folder colour stays `#E5C07B` unless the active theme defines a `FolderIcon` group, a name no third-party theme uses (checked against all 17 installed). Vale defines it; so vale gets its own folder colour and every other theme keeps the old yellow.
- **Octo:** the existing `ColorScheme` rebuild first re-reads octo's `config.colors` from standard groups (`DiagnosticOk/Error/Warn/Info`, `Function`, `Statement`, `LineNr`, `Normal`), so octo follows every theme, vale included. No vale-specific octo module.
- **rainbow-delimiters:** its `RainbowDelimiter*` groups are defined in the integration module. Whether to adopt VS Code's bracket-pair colours is decided during picking (D3).

### D10. Reference values are verified before round 1

`reference/vscode_modern.lua` is filled from `microsoft/vscode` `extensions/theme-defaults/themes/` (`dark_modern.json` → `dark_plus.json` → `dark_vs.json` include chain, and the light equivalents). Each value records its source file and the token scope or colour key. The values quoted during exploration were from memory and are not trusted until they are checked.

## Risks / Trade-offs

- [Coverage drifts as plugins are added] → The integration list is in the spec, and there is a task to grep plugins' `nvim_set_hl`/`default = true` groups. When a plugin is added later, its integration file belongs in the same change.
- [Live preview with themery or lab is slow if loads are heavy] → Loads build a few hundred tables with no I/O except the palette `dofile`. If it's measurably slow (>20 ms), cache the merged groups per palette mtime.
- [Treesitter capture names change across nvim-treesitter `main` updates] → Target Neovim 0.12's documented capture list, with `:Inspect` spot-checks in the lab.
- [Roslyn/jdtls slow to attach in the lab] → Semantic-token slots are picked last within the "loud" phase. The lab shows whether an LSP is attached per sample in the window's winbar.
- [Lock writer fails on a hand-reformatted palette] → It refuses loudly (D6). The palette format rule (one entry per line) is written in the palette file's header comment.
- [Picking stalls, leaving placeholders] → Both palettes start fully populated with VS Code reference values, so vale is usable and looks like VS Code Modern from the first commit. Picking only refines it.

## Migration Plan

This is additive. After the Themery change, users with a persisted Themery selection keep it. Only first launches (with no state) default to vale-night. Rollback means removing the two Themery entries and restoring the `catppuccin-mocha` fallback. The lualine and neo-tree fallbacks keep other themes unchanged.

## Open Questions

- Exact base shade count (8 may become 10 once foundation picking shows where sidebars, floats and cursorline need separate steps). This can be answered during picking without changing structure.
