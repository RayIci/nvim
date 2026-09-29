# Proposal

## Why

The configuration cycles through 17 third-party themes, none tuned to how the user reads code, and making a personal one by editing Lua tables is slow and blind. vale turns theme-making into a tool: a browser studio, served by Neovim, where every colour and colour role of a theme is visible at once, previewed live on real code in both the page and Neovim, and saved as plain-data files that stay portable to terminal/tmux/prompt themes later. vale-night and vale-day, anchored on VS Code Modern, are the first themes it produces and edits.

## What Changes

- Add the **vale engine**: a theme format (`themes/<name>/night.lua|day.lua` pure-data palettes with identical keys, plus optional `semantics.lua` overrides) kept in the configuration directory outside the plugin code, and a loader that turns a theme variant into a complete colorscheme `<name>-<variant>` covering editor UI, Vim syntax, treesitter, LSP semantic tokens, diagnostics, terminal colours and one integration module per installed UI plugin.
- **Layered semantics**: a shared default role mapping (VS Code's), overridable per theme and per variant, including "plain foreground" for a role.
- Generated per theme variant: `colors/<name>-<variant>.lua` and a lualine theme shim; every theme defines `FolderIcon`.
- Keep a verified **VS Code Modern reference palette** (sourced from `microsoft/vscode`) as the starting point for new themes; no reference plugin is installed.
- Add the **vale studio**: `:Vale`, `:Vale new <name>`, `:Vale edit <name>`, `:Vale stop`. Neovim serves a local page (127.0.0.1, token-protected, plain HTML/CSS/JS, no dependencies) and opens it in the browser. The page lists themes, creates new ones (dark/light/both, from VS Code or a copy of an existing theme), and edits a theme with every slot visible: hex input for custom colours, picker, reset, contrast, generated variations, and a colour selector per semantic role. Changes preview live in the page (code samples coloured by Neovim) and in Neovim itself; nothing is written until Save, which edits only changed palette lines.
- Ship **vale-night / vale-day** as the first theme (`themes/vale/`), seeded from VS Code Modern and tuned in the studio.
- **BREAKING** (within this unreleased change): the in-Neovim `:ValeLab` tuning tab and its hand-written candidate lists are replaced by the studio.
- Integrate with the existing UI without the configuration naming vale: Themery lists every colorscheme in the configuration's own `colors/` directory at the top (so new themes appear automatically) and falls back to `vale-night` on first launch; lualine labels, octo's palette and the neo-tree folder colour come from the active theme's highlight groups.

## Capabilities

### New Capabilities
- `vale-engine`: theme format, layered semantics, loader and generated colorschemes, highlight coverage and plugin integrations, lualine theme, terminal colours, VS Code reference palette, `FolderIcon` hook.
- `vale-studio`: the browser studio — commands, local server and access control, theme creation, the all-slots editor with custom colours, variations and role selectors, live preview in page and Neovim, save/discard.

### Modified Capabilities
- `git-integration`: octo's colours follow the active colorscheme.
- `ui-shell`: the theme switcher lists the configuration's own colorschemes (discovered from `colors/`) at the top and defaults to `vale-night` on first launch; statusline labels and folder icons follow the active theme.

## Impact

- New code: `lua/vale/**` (engine, groups, integrations, studio server and page assets, samples, reference), `themes/vale/`, generated `colors/*.lua` and `lua/lualine/themes/*.lua`.
- Modified: `lua/plugins/theme.lua` (colors/ discovery, default, `:Vale` command), `lua/plugins/lualine.lua` (theme-derived label colours), `lua/plugins/neotree.lua` (`FolderIcon` hook), `lua/plugins/octo.lua` (theme-derived octo palette).
- Removed (built earlier in this change): `lua/vale/lab/` tab UI and `candidates.lua`; `lua/vale/palettes/` moves to `themes/vale/`.
- No new plugin or system dependencies (uses `vim.uv` and `vim.ui.open`).
- Out of scope: SSH/remote use of the studio; deleting themes from the studio; exporting ghostty/kitty/wezterm/tmux/starship themes (the palette format keeps this possible later).
