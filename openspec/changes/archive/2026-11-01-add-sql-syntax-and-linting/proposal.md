## Why

The sql pack already ships a complete vim-dadbod stack — DB engine, dadbod-ui drawer, and schema-aware dadbod completion — but three editing-layer pieces are missing: it declares no treesitter parser (so SQL falls back to Vim's legacy regex syntax), has no linting, and formats with sql-formatter's pure pretty-printing rather than a dialect-aware tool. Adding modern syntax highlighting plus dialect-aware linting and formatting completes the "query databases, everything" experience without touching the connection/completion hub that dadbod already owns.

## What Changes

- Add the `sql` treesitter parser to the sql pack for modern highlighting (and better dadbod-ui result rendering).
- Add **sqlfluff** as the sql linter (nvim-lint) and **replace sql-formatter with sqlfluff** as the formatter (conform), so linting and formatting share one dialect-aware tool.
- Swap the pack's mason tool `sql-formatter` → `sqlfluff`.
- Handle sqlfluff's mandatory dialect across many databases (postgres, mysql, sqlite, tsql, snowflake, bigquery, databricks): defer to a project `.sqlfluff` config when present, and inject a permissive fallback dialect (`ansi`) only when no project config exists, so unconfigured buffers don't error.
- Keep vim-dadbod, dadbod-ui, and dadbod-completion unchanged — dadbod remains the single connection and schema-completion source of truth; no SQL LSP is added.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `language-packs`: The SQL language pack gains the `sql` treesitter parser and dialect-aware sqlfluff linting + formatting (replacing sql-formatter), while retaining the dadbod UI/engine/completion.

## Impact

- `lua/langs/sql.lua` — add `treesitter = { "sql" }`; change `formatters` to `{ sql = { "sqlfluff" } }`; add `linters = { sql = { "sqlfluff" } }`; swap mason `sql-formatter` → `sqlfluff`; add a dialect-fallback helper wiring conform's + nvim-lint's sqlfluff to project config with an `ansi` fallback.
- New mason tool: `sqlfluff`. Removed: `sql-formatter`.
- No new plugins; no framework changes (all via existing `treesitter`/`linters`/`formatters`/`mason` pack fields).
