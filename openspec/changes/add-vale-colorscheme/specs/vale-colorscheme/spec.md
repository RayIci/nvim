# Spec Delta

## Purpose

Provides vale, the user's personal Neovim colorscheme with a dark and a light variant anchored on VS Code Modern, built on a portable plain-data palette so every editor surface and plugin is coloured coherently and the palette can be translated to other tools later.

## ADDED Requirements

### Requirement: Two loadable variants
The configuration SHALL provide the colorschemes `vale-night` (dark) and `vale-day` (light). Loading either SHALL clear existing highlights, set `g:colors_name` to the variant name, and set `background` to `dark` or `light` respectively.

#### Scenario: Load the dark variant
- **WHEN** the user runs `:colorscheme vale-night`
- **THEN** `vim.g.colors_name` is `vale-night`, `vim.o.background` is `dark`, and the `Normal` group uses the night palette's editor background and foreground

#### Scenario: Load the light variant
- **WHEN** the user runs `:colorscheme vale-day`
- **THEN** `vim.g.colors_name` is `vale-day`, `vim.o.background` is `light`, and the `Normal` group uses the day palette's editor background and foreground

#### Scenario: Switch between variants
- **WHEN** the user loads `vale-night` and then `vale-day`
- **THEN** no highlight group keeps a colour from the night palette

### Requirement: Portable plain-data palette
Each variant SHALL have exactly one palette file that contains only literal data: no functions, no `require`, no computed values. Every colour SHALL be a `#RRGGBB` hex string (alpha pre-blended against the editor background) or, in the `ansi` and `ui` blocks, the name of a colour defined in `base`, `accent` or `signal`. The palette SHALL have the blocks `base` (background-to-foreground shades), `accent` (named hues), `signal` (diagnostic and git status colours), `ansi` (exactly 16 entries named `black`, `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`, `white` and their `bright_` counterparts, mapping to terminal slots 0–15), and `ui` (at least `bg`, `fg`, `cursor`, `selection`, `border`, `accent`). Both variants' palettes SHALL have identical key sets. Each colour entry SHALL carry a comment describing its role.

#### Scenario: Palette is readable outside Neovim
- **WHEN** a palette file is evaluated by a plain Lua interpreter with no Neovim APIs available
- **THEN** it returns a table without error

#### Scenario: Variant keys match
- **WHEN** the night and day palettes are compared
- **THEN** they define the same keys in every block

#### Scenario: Name references resolve
- **WHEN** any `ansi` or `ui` entry is a colour name rather than hex
- **THEN** that name exists in the same palette's `base`, `accent` or `signal` block

### Requirement: Semantic role layer
Highlight groups SHALL NOT reference palette hex values directly. They SHALL reference semantic roles (for example keyword, control-flow keyword, function, string, type, variable, parameter, property, constant, number, comment, diagnostic error/warn/info/hint, git add/change/delete), and each role SHALL map to a palette colour, so that re-assigning a role changes every group that uses it.

#### Scenario: Re-map a role
- **WHEN** the semantic mapping for "keyword" is changed to a different palette colour and the colorscheme is reloaded
- **THEN** every keyword-related group (Vim syntax, treesitter captures, LSP semantic tokens) shows the new colour

### Requirement: Editor, syntax, treesitter and LSP coverage
The colorscheme SHALL define the built-in editor UI groups (see `:h highlight-groups`), the standard Vim syntax groups, treesitter capture groups (`@…`, see `:h treesitter-highlight-groups`), LSP semantic token groups (`@lsp.type.*`, `@lsp.mod.*`, `@lsp.typemod.*`), and diagnostic groups (base, virtual text, underline, sign, floating). LSP semantic token groups SHALL link to or match their treesitter equivalents so a token keeps the same colour whether or not a language server is attached.

#### Scenario: Semantic tokens agree with treesitter
- **WHEN** a C# file is opened and roslyn attaches, applying semantic tokens
- **THEN** class names, method names, parameters and properties keep the same colours they had under treesitter alone

#### Scenario: Diagnostics are distinct
- **WHEN** a buffer shows an error, a warning, an info and a hint diagnostic
- **THEN** each severity uses its own colour for virtual text, sign and underline

### Requirement: Installed plugin integrations
The colorscheme SHALL define the highlight groups of every UI-affecting plugin installed by the configuration, including at least: gitsigns, diffview, neogit, git-conflict, octo, telescope, neo-tree, bufferline, lualine, barbecue/navic, which-key, noice, snacks, trouble, todo-comments, indent-blankline, rainbow-delimiters, flash, illuminate, blink.cmp, lspsaga, lightbulb, nvim-dap, nvim-dap-ui, nvim-dap-virtual-text, neotest, overseer, grug-far, render-markdown, toggleterm, nvim-ufo, multicursor, sidekick, mason, and window-picker. Each integration SHALL live in its own module.

#### Scenario: Integration is present
- **WHEN** vale is active and the user opens telescope, neo-tree, and a diffview
- **THEN** their windows, borders, selections and diff regions use vale colours, not colours linked from a previous theme or the Neovim default

#### Scenario: Diff readability
- **WHEN** a diff is shown in diffview or neogit
- **THEN** added, deleted, changed and changed-text regions are distinguishable from each other and the foreground text stays readable on each

### Requirement: Terminal colours
Loading a vale variant SHALL set `vim.g.terminal_color_0` through `vim.g.terminal_color_15` from that palette's `ansi` block in slot order (`black` = 0 … `white` = 7, `bright_black` = 8 … `bright_white` = 15).

#### Scenario: Terminal buffer colours
- **WHEN** vale-night is active and the user opens a toggleterm terminal running `ls --color`
- **THEN** the ANSI colours shown match the night palette's `ansi` slots

### Requirement: VS Code Modern reference palette
The configuration SHALL keep a reference palette with the VS Code Dark Modern and Light Modern values for every slot vale tunes, sourced from the theme files in the `microsoft/vscode` repository, with the source file recorded alongside the values. No reference colorscheme plugin SHALL be installed.

#### Scenario: Reference values are traceable
- **WHEN** the user looks up a reference value such as the dark keyword colour
- **THEN** the reference records the value and which VS Code theme file it came from

### Requirement: Folder icon hook
The colorscheme SHALL define a `FolderIcon` highlight group with the palette's folder colour, so theme-agnostic configuration can pick up vale's folder colour without referencing vale.

#### Scenario: Folder colour under vale
- **WHEN** vale-night is active and neo-tree is open
- **THEN** folder icons use the night palette's folder colour
