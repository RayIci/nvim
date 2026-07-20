## ADDED Requirements

### Requirement: Buffer tooling indicators in the statusline
The statusline SHALL show icon-distinguished, buffer-scoped indicators for the active LSP clients, conform formatters, and nvim-lint linters of the current buffer. Each indicator SHALL read global state keyed by the current buffer (`vim.lsp.get_clients`, `conform.list_formatters`, `lint.linters_by_ft`), carry its own icon and color so the three are visually distinguishable, and render nothing when its list is empty.

#### Scenario: Indicators reflect the current buffer
- **WHEN** a Python buffer is open with basedpyright + ruff attached, ruff configured as formatter, and ruff + mypy as linters
- **THEN** the statusline shows an LSP indicator listing the clients, a formatter indicator listing the formatters, and a linter indicator listing the linters, each with its distinguishing icon

#### Scenario: Empty indicators hide
- **WHEN** a buffer has no linters configured for its filetype
- **THEN** the linter indicator renders nothing (no empty icon or label)

### Requirement: Registrable statusline widgets
The statusline SHALL include a bridge component that renders statusline widgets registered by any code — language packs (via the framework's `statusline` field) or a plugin's own setup — through a public `register()` API on the statusline module, evaluated at render time so widgets from lazily-loaded plugins appear once available. Registration SHALL append (never replace), so registrants do not clobber one another regardless of order. A widget SHALL be shown only when its `cond` (if any) holds and its `render()` returns a non-empty string. The Python pack SHALL contribute a venv widget that shows `🐍 <venv-name>` for Python buffers and renders nothing when no virtualenv is active.

#### Scenario: Active venv shown for Python buffers
- **WHEN** a virtualenv is selected (via venv-selector) and a Python buffer is focused
- **THEN** the statusline shows `🐍 <venv-name>`

#### Scenario: No venv hides the widget
- **WHEN** no virtualenv is active, or the focused buffer is not Python
- **THEN** the venv widget renders nothing

#### Scenario: A plugin registers its own widget
- **WHEN** a plugin calls the statusline module's `register()` in its setup with a widget spec
- **THEN** that widget renders in the statusline alongside pack-contributed widgets, without either clobbering the other
