## MODIFIED Requirements

### Requirement: SQL language pack
The configuration SHALL provide a sql pack with the `sql` treesitter parser for syntax highlighting, sqlfluff for both linting (nvim-lint) and formatting (conform), vim-dadbod + vim-dadbod-ui + vim-dadbod-completion, a `<leader>D` database keymap group (toggle UI, add connection, find buffer), buffer-local mappings in dbui/dbout/sql buffers replicating the old config's Plug mappings (open, delete, execute query, save query, jump to foreign key, toggle layout), and a dadbod completion source for sql/mysql/plsql filetypes. sqlfluff SHALL resolve its dialect from a dedicated project config (`.sqlfluff` or `.sqlfluff.cfg`) found by searching upward from the buffer, and SHALL NOT force a dialect when one is present. Linting SHALL fall back to the permissive `ansi` dialect only when no such config exists, so unconfigured buffers lint without a "no dialect" error; formatting SHALL run only when a dedicated config is present (no fallback), since `sqlfluff fix` under a generic dialect could rewrite dialect-specific SQL incorrectly.

#### Scenario: SQL syntax highlighting
- **WHEN** a `.sql` file is opened
- **THEN** treesitter highlights it using the `sql` parser

#### Scenario: Database UI
- **WHEN** the user presses `<leader>DD`
- **THEN** the DBUI drawer toggles, and in the drawer `o`/`<cr>` opens the selected item

#### Scenario: SQL completion
- **WHEN** the user edits a SQL buffer connected to a database
- **THEN** the completion menu offers dadbod-sourced table/column candidates

#### Scenario: Dialect-aware linting from project config
- **WHEN** a SQL buffer is linted or formatted in a project that has a `.sqlfluff` declaring `dialect = postgres`
- **THEN** sqlfluff runs as PostgreSQL and Neovim does not pass `--dialect` (the project config wins via `--stdin-filename`/cwd discovery)

#### Scenario: Fallback dialect for linting without project config
- **WHEN** a SQL buffer is linted in a project with no `.sqlfluff`
- **THEN** sqlfluff lints with the `ansi` fallback dialect rather than failing with "no dialect"

#### Scenario: Formatting skipped without project config
- **WHEN** a SQL buffer is formatted in a project with no `.sqlfluff`
- **THEN** sqlfluff formatting does not run (no generic-dialect rewrite of dialect-specific SQL)
