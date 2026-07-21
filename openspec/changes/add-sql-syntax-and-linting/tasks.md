## 1. Syntax highlighting

- [x] 1.1 Add `treesitter = { "sql" }` to the sql pack in `lua/langs/sql.lua` (verify the `sql` parser exists in nvim-treesitter main).

## 2. sqlfluff wiring (lint + format) with dialect fallback

- [x] 2.1 Swap the pack's mason tool `sql-formatter` → `sqlfluff`.
- [x] 2.2 Change `formatters` to `{ sql = { "sqlfluff" } }` and add `linters = { sql = { "sqlfluff" } }`.
- [x] 2.3 Add a helper that searches upward from a buffer for a dedicated sqlfluff config (`.sqlfluff`/`.sqlfluff.cfg`) and returns its dir (or nil). Only dedicated files count, to avoid forcing `ansi` over a `pyproject.toml` `[tool.sqlfluff]` config.
- [x] 2.4 Formatting (conform): partial-override `require("conform").formatters.sqlfluff` with `require_cwd = true` + `cwd = root_file({ ".sqlfluff", ".sqlfluff.cfg" })` so it runs only where a config exists (dialect always known); no `ansi` fallback for formatting.
- [x] 2.5 Linting (nvim-lint): register `require("lint").linters.sqlfluff` as a function that builds args for the current buffer — `--stdin-filename <buf>` for config discovery, plus `--dialect ansi` only when no config exists; the sqlfluff JSON parser is preserved.

## 3. Verify

- [x] 3.1 Launch nvim, open a `.sql` file: confirm treesitter highlighting is active (`:InspectTree`) and `:Mason` shows `sqlfluff` installing; `sql-formatter` no longer required.
- [x] 3.2 In a project WITHOUT a `.sqlfluff`: save/format a SQL buffer → sqlfluff runs with `ansi` (no "no dialect" error); lint diagnostics appear.
- [x] 3.3 In a project WITH a `.sqlfluff` (`dialect = postgres`): confirm Postgres-specific syntax (e.g. `::` cast) is accepted and Neovim does not override the dialect.
- [x] 3.4 Confirm dadbod UI/completion still work unchanged (`<leader>DD`, dadbod candidates in a connected buffer).
- [x] 3.5 Run `openspec validate add-sql-syntax-and-linting --strict`.
