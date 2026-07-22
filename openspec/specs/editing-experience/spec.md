# editing-experience Specification

## Purpose
TBD - created by syncing change setup-nvim-config. Update Purpose after archive.

## Requirements

### Requirement: Treesitter syntax highlighting
The configuration SHALL use nvim-treesitter (`main` branch) to install parsers declared by language packs and start treesitter highlighting for those filetypes, using the `main`-branch API (`require('nvim-treesitter').install()` + `vim.treesitter.start()`), not the deprecated `configs.setup` API. On top of pack-declared parsers, the configuration SHALL always install a common base set including at least: `vim`, `vimdoc`, `query`, `markdown`, `markdown_inline`, `regex`, `bash`, `diff`, `json`, `yaml`, `toml`, `xml`, `http`, `c`, `lua`, `luadoc`, `make`, `dockerfile`, `editorconfig`, the git parsers (`gitcommit`, `gitignore`, `git_rebase`, `git_config`, `gitattributes`), and `dap_repl`. The merged parser list SHALL be deduplicated.

#### Scenario: Highlighting active
- **WHEN** a file with an installed parser is opened
- **THEN** treesitter highlighting is active for that buffer

#### Scenario: Git file highlighting without a git language pack
- **WHEN** an interactive rebase todo or `.gitignore` file is opened
- **THEN** treesitter highlighting is active via the always-installed git parsers

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

### Requirement: AI inline completion via copilot.lua
The configuration SHALL provide Copilot ghost-text suggestions through zbirenbaum/copilot.lua (the old-config engine) backed by the mason-installed copilot-language-server binary, with the old-config keys: `<C-t>` accepts the current suggestion line, `<C-w>` accepts the next word, `<M-l>` accepts the whole suggestion, `<M-]>`/`<M-[>` cycle alternatives, and `<C-]>` dismisses. Accept keys SHALL act only on a visible suggestion (`trigger_on_accept = false`); `<C-w>` is a direct global map that is a harmless no-op without a suggestion (built-in insert delete-word is intentionally not preserved), while `<C-t>` passes through to its built-in behavior. Ghost text SHALL NOT linger after leaving insert mode, regardless of whether insert mode is exited with `<Esc>` or `<C-c>`.

#### Scenario: No-op without suggestion
- **WHEN** no ghost suggestion is visible and the user presses `<C-w>` in insert mode
- **THEN** nothing happens (no deletion, no mode change)

#### Scenario: Accept word then line
- **WHEN** a multi-line ghost suggestion is visible and the user presses `<C-w>` then `<C-t>`
- **THEN** first only the suggestion's next word is inserted, then the remainder of the current suggestion line

#### Scenario: Ghost text accept
- **WHEN** Copilot is signed in and the user pauses while typing code
- **THEN** a ghost-text suggestion renders and `<M-l>` inserts all of it

#### Scenario: Dismiss
- **WHEN** a ghost-text suggestion is visible and the user presses `<C-]>`
- **THEN** the suggestion disappears without inserting text

#### Scenario: No lingering ghost text on Ctrl-C
- **WHEN** a suggestion is visible and the user exits insert mode with `<C-c>`
- **THEN** the ghost text is cleared

### Requirement: Sidekick CLI AI assistant
The configuration SHALL provide an AI assistant workflow through `folke/sidekick.nvim` CLI integration, replacing CopilotChat as the primary chat/review/explain interface. Sidekick SHALL use the `<leader>a` key namespace for selecting, toggling, focusing, and sending prompts to AI CLI tools, and SHALL support at least Claude CLI and Copilot CLI when those tools are installed.

#### Scenario: Select and open AI CLI
- **WHEN** the user invokes the configured AI CLI selection keymap
- **THEN** Sidekick presents available CLI tools and sessions
- **AND** selecting a tool attaches to or starts that CLI inside Neovim

#### Scenario: Toggle AI CLI
- **WHEN** the user invokes the configured AI toggle keymap
- **THEN** Sidekick opens, attaches, toggles, or asks for a CLI session using its native behavior

### Requirement: Native Sidekick CLI session behavior
The configuration SHALL use Sidekick's native CLI/session behavior for normal AI actions. The configuration SHALL NOT add a custom default-session routing layer for normal Sidekick prompts; Sidekick SHALL decide whether to use an active session, attach an existing session, start a new session, or show its selector.

#### Scenario: Sidekick owns session selection
- **WHEN** the user invokes normal AI keymaps such as toggle, explain, review, diagnostics, or prompt picker
- **THEN** those keymaps call Sidekick's native CLI APIs directly
- **AND** Sidekick owns session selection and attachment behavior

#### Scenario: Tmux-backed sessions
- **WHEN** `tmux` is installed and the user starts or attaches a Sidekick CLI
- **THEN** Sidekick uses tmux-backed session persistence
- **AND** if the selected session is already running externally, default AI keymaps attach to and send prompts to that existing session without forcing a new Neovim terminal
- **AND** when `tmux` is unavailable, Sidekick falls back to its terminal backend

### Requirement: Sidekick context prompts
The configuration SHALL map explain, review, diagnostics, and commit-message prompts to Sidekick using context variables such as `{this}`, `{selection}`, `{file}`, and `{diagnostics}`. Visual-mode prompt keymaps SHALL send the selected code as context so the user can ask about a specific range.

#### Scenario: Explain visual selection
- **WHEN** the user visually selects code and invokes the explain keymap
- **THEN** the selected code is sent through Sidekick with an explain prompt

#### Scenario: Review current context
- **WHEN** the user invokes the review keymap from normal mode
- **THEN** Sidekick sends a review prompt using the current file or cursor context

#### Scenario: Commit message prompt
- **WHEN** the user invokes the commit-message prompt keymap
- **THEN** the configuration uses the commit-message behavior appropriate for the current buffer
- **AND** outside `gitcommit` buffers, Sidekick sends the prompt asking a CLI to write a commit message for the staged changes
- **AND** outside `gitcommit` buffers, the result is handled interactively in the CLI session

### Requirement: Sidekick NES disabled by default
The configuration SHALL keep Sidekick's Copilot next-edit suggestions disabled by default so existing `copilot.lua` ghost-text completion semantics remain unchanged.

#### Scenario: Inline completion unchanged
- **WHEN** the user types in insert mode after this change
- **THEN** inline ghost-text suggestions are still provided by `copilot.lua`
- **AND** Sidekick does not introduce additional next-edit suggestions unless explicitly enabled in a later change

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

### Requirement: Smart folding
The configuration SHALL provide smart code folding backed by LSP folding ranges when available, with Tree-sitter and indentation fallbacks for buffers where LSP folding is unavailable or incomplete. Folds SHALL remain open by default when a buffer is opened, and the editor SHALL show a small fold column with open/closed fold indicators.

#### Scenario: File opens expanded
- **WHEN** a source file is opened
- **THEN** fold ranges are available for fold commands
- **AND** the file content is not automatically collapsed

#### Scenario: Folding provider fallback
- **WHEN** the attached LSP does not provide folding ranges for the current buffer
- **THEN** the configuration falls back to Tree-sitter or indentation-based folds instead of disabling folding entirely

#### Scenario: Provider-safe fold commands
- **WHEN** the user invokes the configured open-all or close-all fold command
- **THEN** folds are opened or closed without lowering the high default fold level needed for provider-managed folds

### Requirement: Multi-cursor editing
The configuration SHALL provide multi-cursor editing via `jake-stewart/multicursor.nvim`: `<C-n>` (normal and visual) selects the word under the cursor and adds the next matching occurrence per press, `<C-p>` adds the previous match, `q` skips the current match and jumps to the next, `<C-Up>`/`<C-Down>` add a cursor on the line above/below, `<C-Left>`/`<C-Right>` rotate the main cursor, `<leader>ma` adds cursors to all matches, visual-mode `<leader>m` helpers split/match/insert/append across the selection, `<leader>mx` deletes the current cursor, and `<Esc>` clears all cursors (or re-enables them when disabled). The `q` and `<Esc>` bindings live in a buffer-local keymap layer active only while cursors exist, so they take precedence over global mappings (e.g. `<Esc>` → nohlsearch) during a session and revert afterwards. All regions are highlighted and edits are reflected on every cursor in real time.

#### Scenario: Add and skip occurrences
- **WHEN** the user presses `<C-n>` three times on a word and `q` once
- **THEN** three occurrences are selected (the skipped one excluded) and typing a change applies to all selected occurrences live

#### Scenario: Line cursors and clear
- **WHEN** the user presses `<C-Down>` twice to add cursors below and then `<Esc>`
- **THEN** cursors are added on the two lines below and `<Esc>` clears all extra cursors, returning to a single cursor

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
