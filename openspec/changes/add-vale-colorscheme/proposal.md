# Proposal

## Why

The configuration cycles through 17 third-party themes, none of which is tuned to how the user reads code, and plugin colours are patched ad hoc (hardcoded tokyonight hex in lualine, a fixed folder-icon yellow in neo-tree). A personal colorscheme, anchored on the familiar VS Code Modern look and chosen colour by colour against real code, gives one coherent, fully integrated theme — and its palette, kept as plain data, becomes the single source for future terminal/tmux/prompt themes.

## What Changes

- Add **vale**, an in-tree colorscheme with two variants: `vale-night` (dark, anchored on VS Code Dark Modern) and `vale-day` (light, anchored on VS Code Light Modern), loadable via `:colorscheme vale-night` / `:colorscheme vale-day`.
- Structure it in three layers: a **palette** (pure-data Lua, identical keys per variant, portable contract with `base`, `accent`, `ansi`, `ui` blocks), a **semantics** layer (roles → palette names), and **highlight modules** (editor, syntax, treesitter, LSP semantic tokens, diagnostics, and one integration module per installed plugin).
- Set the 16 terminal colours (`vim.g.terminal_color_0..15`) from the palette's `ansi` block.
- Keep a verified **VS Code Modern reference palette** (sourced from the `microsoft/vscode` theme JSON) in-tree; no reference plugin is installed.
- Add **`:ValeLab`**, an interactive tuning workspace: a grid of per-language sample files that all exercise the same token checklist, a side panel with the current slot, 3–5 candidate swatches (candidate 1 always the VS Code value) with contrast ratios, live repaint when cycling candidates, locking the chosen value into the palette file, and hot reload on palette save.
- Integrate with the existing UI: add both variants to the Themery picker and make `vale-night` the first-launch fallback (replacing `catppuccin-mocha`); ship a lualine theme; make the lualine component colours and octo's palette come from the active theme's standard highlight groups, and let a theme-defined `FolderIcon` group override the neo-tree folder colour — without the configuration referencing vale.

## Capabilities

### New Capabilities
- `vale-colorscheme`: the vale colorscheme itself — variants, layered palette/semantics/highlights structure, portable palette contract, terminal colours, plugin integration coverage, and the VS Code reference palette.
- `vale-lab`: the `:ValeLab` interactive colour-tuning workspace — samples, candidate cycling with live preview, contrast readout, locking into the palette, hot reload.

### Modified Capabilities
- `git-integration`: octo's colours follow the active colorscheme.
- `ui-shell`: the "Theme switcher with persistence" requirement now includes the vale variants in the picker and names `vale-night` as the first-launch default.

## Impact

- New code: `colors/vale-night.lua`, `colors/vale-day.lua`, `lua/vale/**` (palettes, reference, semantics, highlight groups, integrations, lab, samples).
- Modified: `lua/plugins/theme.lua` (Themery entries, default, `:ValeLab`), `lua/plugins/lualine.lua` (theme-derived label colours), `lua/plugins/neotree.lua` (`FolderIcon` hook), `lua/plugins/octo.lua` (theme-derived octo palette).
- No new plugin dependencies. The octo `ColorScheme` workaround is extended to re-read octo's palette from the active theme.
- Out of scope: ghostty/kitty/wezterm/tmux/starship/lazygit/btop themes (the palette format is designed to make them easy later).
