## Context

The sql pack (`lua/langs/sql.lua`) has vim-dadbod (engine), vim-dadbod-ui (drawer), vim-dadbod-completion (schema completion wired into blink for sql/mysql/plsql), sql-formatter formatting, and a `<leader>D` keymap surface. It declares no treesitter parser and no linter. The user works across many SQL dialects — PostgreSQL, MySQL/MariaDB, SQLite, MSSQL, Snowflake, BigQuery, and Databricks — and wants syntax highlighting, linting, and completion, keeping dadbod as the completion hub (no LSP).

## Goals / Non-Goals

**Goals**
- Modern treesitter highlighting for SQL.
- Dialect-aware linting and formatting via a single tool (sqlfluff), across all the dialects above.
- Zero disruption to the dadbod engine/UI/completion.

**Non-Goals**
- No SQL LSP (sqls/postgrestools). dadbod stays the single connection + schema-completion source; an LSP would duplicate connection config and completions.
- No heavier UI (dbee).
- Not managing per-project dialect config *for* the user — projects own their `.sqlfluff`.

## Decisions

### D1: sqlfluff for both linting and formatting (replace sql-formatter)
Use sqlfluff as the nvim-lint linter and the conform formatter, dropping sql-formatter.
- *Why:* one dialect-aware tool for both, consistent rules between lint and format, wide dialect coverage (incl. `databricks`, `tsql`, `snowflake`, `bigquery`).
- *Trade-off:* sqlfluff's `format` is rule-fix-driven and more opinionated than sql-formatter's pretty-printing. Accepted per the user's choice; easy to revert formatting to sql-formatter while keeping sqlfluff lint if it proves too aggressive.
- *Alternative rejected:* sqruff (faster, Rust) — fewer dialects and less mature; sqlfluff's dialect breadth matters more here.

### D2: Dialect resolution — config-gated formatting, `ansi`-fallback linting
sqlfluff requires a dialect. With many dialects, Neovim must not hardcode or force one, and CLI `--dialect` overrides config files — so forcing it would silently break per-project dialects. Detection counts only a dedicated `.sqlfluff`/`.sqlfluff.cfg` (a bare `pyproject.toml`/`setup.cfg` may have no `[sqlfluff]` section; mis-detecting one would make us force `ansi` over a real config).

Linting and formatting are treated **asymmetrically**, because `fix` mutates code but `lint` does not:
- **Formatting (conform):** run **only** where a dedicated config exists (`require_cwd` + `cwd = root_file({.sqlfluff, .sqlfluff.cfg})`, sqlfluff's default `fix -` args unchanged). The dialect is therefore always known; there is **no** `ansi` fallback for formatting, since `sqlfluff fix` under a generic dialect could rewrite dialect-specific SQL incorrectly.
- **Linting (nvim-lint):** defer to the project config via `--stdin-filename <buf>` so discovery follows the file (not Neovim's cwd), and inject `--dialect ansi` **only** when no `.sqlfluff` is found — lint is non-destructive, and a permissive fallback beats sqlfluff erroring with "no dialect specified".
- *Implementation:* the linter is registered as a function (nvim-lint calls it per run) that builds args for the current buffer; the formatter is a partial conform override (merged over sqlfluff's built-in) that only swaps the config-file list and keeps `require_cwd`.

### D3: Keep dadbod completion; no LSP
dadbod-completion already provides schema-aware suggestions from the live connection for sql/mysql/plsql. Leave it as-is; do not add an LSP source.
- *Why:* avoids double completion and a second connection-config surface.

## Risks / Trade-offs

- **sqlfluff not installed yet / slow first run** → mason installs `sqlfluff`; nvim-lint runs on save, conform on format — both tolerate the tool arriving asynchronously. *Mitigation:* mason ensure_installed already handles this like other pack tools.
- **`ansi` fallback flags dialect-specific syntax** (e.g. Postgres `::` casts) in unconfigured projects → shows as lint noise. *Mitigation:* documented; the fix is a one-line project `.sqlfluff`. The fallback only affects projects that opted out of configuring a dialect.
- **Exotic-dialect querying** (Snowflake/BigQuery/Databricks) via dadbod depends on dadbod adapters + vendor CLIs; out of scope here. Editing/highlighting/lint/format still work for those dialects.

## Migration Plan

Additive/replacement within one pack file; no persisted state. Rollback = restore sql-formatter in `formatters`/`mason` and drop the treesitter/linter/helper additions. Removing sqlfluff from `formatters` (keeping it in `linters`) is the partial rollback if its formatting is too opinionated.

## Open Questions

None blocking. If the `ansi` fallback proves noisy in practice, a future refinement could pick a smarter default dialect from a per-user setting.
