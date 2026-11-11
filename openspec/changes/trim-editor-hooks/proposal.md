# Proposal

## Why

Several features do their work on every cursor move, keystroke or mode change, through extra plugins or more often than needed:
- nvim-ufo plus promise-async request LSP folding ranges on every text change, which Neovim 0.12 can do natively with `vim.lsp.foldexpr()`;
- barbecue redraws a winbar on every cursor move, and needs a scheduled winbar-clear hack for terminals and panels;
- nvim-lint runs every configured linter on every InsertLeave, even when nothing changed. Slow tools such as mypy and checkstyle restart on each Esc;
- in Python, ruff reports the same diagnostics twice: once through its language server and once as a linter.

The user also wants the display toggles (lightbulb, rainbow brackets, inlay hints, code lenses, breadcrumbs) to persist across restarts. Separately, `]t`/`[t` are mapped by both neotest and todo-comments, so the test jumps never worked.

Apply after `move-explorer-to-snacks`.

## What Changes

- **Folding** uses Neovim's native expression folding: LSP folding ranges when the attached server provides them, otherwise treesitter, otherwise indentation. Files open unfolded, the fold column stays, and `zR`/`zM`/`zr`/`zm` are Neovim's own commands. `zU` (close child folds) stays. nvim-ufo and promise-async are removed.
- **Breadcrumbs** move from the winbar to the statusline: the navic symbol path of the cursor, for code buffers with a document-symbol server. `<leader>ub` toggles them, persisted. barbecue is removed, and so is its winbar-clear workaround.
- **Linters** run when a buffer is opened, when it is entered, when insert mode ends and when it is saved.
  - Entering a buffer or ending insert mode does not re-run linters when the buffer has not changed since its last lint.
  - Linters never run while typing.
  - `<leader>ud` (live diagnostics) now only controls whether diagnostics update in insert mode.
- **Python:** ruff is removed from the python pack's nvim-lint linters. Its diagnostics keep coming from the ruff language server, and mypy stays as a linter.
- **Persisted toggles** (restored on every start):
  - `<leader>ul` code-action lightbulb (new key);
  - `<leader>li` inlay hints (global; now persisted);
  - `<leader>lct` code lenses (now persisted globally rather than per session);
  - `<leader>ub` breadcrumbs (new key);
  - `<leader>ur` rainbow brackets (already persisted).
- **TODO jumps:** `]t`/`[t` belong to todo-comments, which is how they behave today. neotest's next/previous test stays on `<leader>tnn`/`<leader>tnp`, and `]T`/`[T` (failed tests) are unchanged.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `editing-experience`: folding provider and fold commands; linting triggers.
- `lsp-and-diagnostics`: the live-diagnostics toggle no longer runs linters while typing; new persisted display toggles.
- `ui-shell`: breadcrumbs move from the winbar to the statusline with a persisted toggle; tooling-indicator example updated for the python linters; TODO navigation keys stated.
- `language-packs`: the python pack's ruff diagnostics come from its language server only.
- `testing`: `]t`/`[t` are no longer test motions.

## Impact

- Removed: nvim-ufo, promise-async, barbecue.nvim, `lua/plugins/barbecue.lua`, `lua/plugins/folding.lua` (replaced by native fold setup in `lua/plugins/lsp.lua` and `lua/plugins/treesitter.lua`).
- Edited: `lua/config/options.lua`, `lua/plugins/lsp.lua`, `lua/plugins/treesitter.lua`, `lua/plugins/lint.lua`, `lua/plugins/lightbulb.lua`, `lua/plugins/lualine.lua`, `lua/plugins/neotest.lua`, `lua/langs/python.lua`, `README.md`.
- Prefs keys added: `lightbulb`, `inlay_hints`, `codelens`, `breadcrumbs`. `vim.g.codelens_enabled` in session files is ignored from now on.
