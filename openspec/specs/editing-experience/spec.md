# editing-experience Specification

## Purpose
TBD - created by syncing change setup-nvim-config. Update Purpose after archive.

## Requirements

### Requirement: Treesitter syntax highlighting
The configuration SHALL use nvim-treesitter (`main` branch) to install parsers declared by language packs and start treesitter highlighting for those filetypes, using the `main`-branch API (`require('nvim-treesitter').install()` + `vim.treesitter.start()`), not the deprecated `configs.setup` API.

#### Scenario: Highlighting active
- **WHEN** a file with an installed parser is opened
- **THEN** treesitter highlighting is active for that buffer

### Requirement: Completion via blink.cmp
The configuration SHALL provide as-you-type completion with blink.cmp (LSP, path, snippet, buffer sources), pinned to a stable release so prebuilt fuzzy binaries are used. The menu SHALL use VSCode-like kind icons and column layout, documentation SHALL auto-show as the user scrolls through candidates, and snippets from friendly-snippets SHALL be expandable via native `vim.snippet`.

#### Scenario: Completion menu
- **WHEN** the user types in insert mode where a source has candidates
- **THEN** a completion menu with kind icons appears and a candidate can be accepted with the configured key

#### Scenario: Documentation preview while cycling
- **WHEN** the user moves the selection across completion candidates
- **THEN** each candidate's documentation renders automatically in a preview window without extra keypresses

#### Scenario: Snippet expansion
- **WHEN** the user accepts a snippet candidate (e.g. a for-loop snippet)
- **THEN** the snippet expands with jumpable placeholders

### Requirement: Signature help while completing
The configuration SHALL show function signature help (active parameter highlighted) automatically while typing call arguments, rendered by exactly one provider: blink.cmp's signature window. No other plugin (noice or otherwise) SHALL open a second signature window for the same trigger.

#### Scenario: Signature popup
- **WHEN** the user types `(` after a function name with an attached LSP
- **THEN** a single signature window appears highlighting the current parameter as the user types

#### Scenario: No duplicate window
- **WHEN** signature help triggers during completion of a function call
- **THEN** exactly one floating signature window is visible

### Requirement: AI inline completion via native LSP
The configuration SHALL provide Copilot ghost-text suggestions through `vim.lsp.inline_completion` backed by copilot-language-server installed via mason, with keymaps to accept a suggestion and cycle alternatives. No copilot.lua/copilot.vim plugin SHALL be used.

#### Scenario: Ghost text accept
- **WHEN** Copilot is signed in and the user pauses while typing code
- **THEN** a ghost-text suggestion renders and the accept keymap inserts it

### Requirement: Formatting via conform.nvim
The configuration SHALL format with conform.nvim using `formatters_by_ft` assembled from language packs, exposed via a format keymap and optional format-on-save with LSP fallback.

#### Scenario: Manual format
- **WHEN** the user presses the format keymap in a buffer with a registered formatter
- **THEN** conform runs that formatter and the buffer content is updated

### Requirement: Linting via nvim-lint
The configuration SHALL run nvim-lint on save/insert-leave for filetypes with linters registered by language packs, publishing results as diagnostics.

#### Scenario: Lint on save
- **WHEN** a file with a registered linter is written
- **THEN** linter findings appear as diagnostics in the buffer

### Requirement: Editing quality-of-life plugins
The configuration SHALL include nvim-surround (surround operations), nvim-autopairs (bracket pairing integrated with blink.cmp, including newline-between-brackets expansion), and flash.nvim (jump motions), each with default-style keymaps and which-key descriptions.

#### Scenario: Surround operation
- **WHEN** the user performs `ysiw"` on a word
- **THEN** the word is wrapped in double quotes

#### Scenario: Newline between brackets
- **WHEN** the user presses Enter with the cursor between `{` and `}`
- **THEN** the closing bracket moves to its own line and the cursor lands indented on the middle line

### Requirement: Rainbow bracket colors with persisted toggle
The configuration SHALL colorize nested brackets via rainbow-delimiters.nvim and provide a toggle keymap whose state persists across restarts through the prefs module (JSON in `stdpath('state')`).

#### Scenario: Toggle off persists
- **WHEN** the user disables rainbow brackets with the toggle keymap and restarts Neovim
- **THEN** brackets render uncolored after restart until toggled back on

### Requirement: Automatic indentation
The configuration SHALL indent automatically using treesitter `indentexpr` for structural indent and guess-indent.nvim to adopt each file's existing indent style.

#### Scenario: Indent style detected
- **WHEN** a file indented with 2 spaces is opened in a config defaulting to 4
- **THEN** new lines in that buffer use 2-space indentation

### Requirement: Multi-cursor editing
The configuration SHALL provide multi-cursor editing via vim-visual-multi: `<C-n>` selects the word under cursor and adds the next occurrence per press, `q` skips the current occurrence, with all regions highlighted and edits reflected on every cursor in real time.

#### Scenario: Add and skip occurrences
- **WHEN** the user presses `<C-n>` three times on a word and `q` once
- **THEN** three occurrences are selected (the skipped one excluded) and typing a change applies to all selected occurrences live

### Requirement: Reference navigation
The configuration SHALL highlight other references of the symbol under the cursor (vim-illuminate) and provide next/previous-reference keymaps.

#### Scenario: Jump between references
- **WHEN** the cursor rests on a variable with multiple uses and the user presses the next-reference keymap
- **THEN** the cursor jumps to the next reference of that variable in the buffer

### Requirement: Project-wide fuzzy find and replace
The configuration SHALL provide an interactive find-and-replace UI (grug-far.nvim, ripgrep-backed) with live match preview before applying replacements.

#### Scenario: Replace with preview
- **WHEN** the user opens the find-replace UI, enters a search and replacement
- **THEN** matches across the project preview live and applying performs the replacement in all files

### Requirement: Rendered markdown in completion windows
blink.cmp's documentation and signature buffers SHALL render formatted markdown via render-markdown.nvim (their filetypes registered as markdown for treesitter), and the rendering SHALL stay correct while cycling candidates: because blink reuses the same buffer, a buffer-attach listener SHALL re-render on content change.

#### Scenario: Formatted docs on first open
- **WHEN** the completion documentation window opens for a candidate whose docs contain headings, emphasis, and code fences
- **THEN** the window shows rendered markdown (styled headings, concealed markup, highlighted code) rather than raw markup

#### Scenario: Rendering survives candidate cycling
- **WHEN** the user cycles across several completion candidates with markdown documentation
- **THEN** each candidate's documentation window remains rendered, not plain escaped markdown
