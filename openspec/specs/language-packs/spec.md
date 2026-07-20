# language-packs Specification

## Purpose
Concrete per-language packs built on the lang-pack-framework: which LSP servers, formatters, linters, DAP adapters, plugins, and keymaps each supported language gets, and their expected end-to-end behavior.

## Requirements

### Requirement: Shell and config-file language packs
The configuration SHALL provide language packs for bash (bashls + shfmt), docker (dockerls + docker_compose_language_service), json (jsonls with schemastore.nvim schemas, prettier format, jsonlint lint), yaml (yamlls, prettier format, yamllint lint), toml (tombi LSP + tombi format), xml (lemminx + csharpier format), gradle (gradle_ls), and make (mbake format), each installing its mason tools and treesitter parsers.

#### Scenario: JSON with schema
- **WHEN** a `package.json` file is opened
- **THEN** jsonls attaches with schemastore-provided schema validation, and format-on-save runs prettier

#### Scenario: Shell script
- **WHEN** a `.sh` file is opened and saved
- **THEN** bashls is attached and shfmt formats the buffer

### Requirement: Web language pack
The configuration SHALL provide a web pack enabling ts_ls, cssls, css_variables, cssmodules_ls, tailwindcss, and html LSP servers; prettier formatting for javascript, typescript, javascriptreact, typescriptreact, css, and html; eslint_d linting for the JS/TS filetypes and htmlhint for html; and treesitter parsers for html, css, javascript, typescript, and tsx. Astro (astro LSP) and MDX (mdx_analyzer, prettier, mdx.nvim, `.mdx` filetype registration) SHALL be separate packs.

#### Scenario: TypeScript file
- **WHEN** a `.ts` file is opened in a project
- **THEN** ts_ls attaches, eslint_d lints on save, and prettier formats on save

#### Scenario: MDX filetype
- **WHEN** a `.mdx` file is opened
- **THEN** the buffer filetype is `mdx`, mdx_analyzer attaches, and prettier is the registered formatter

### Requirement: Rust language pack
The configuration SHALL provide a rust pack with rust_analyzer, rustfmt formatting, clippy linting, and the rust treesitter parser.

#### Scenario: Rust file
- **WHEN** a `.rs` file is opened
- **THEN** rust_analyzer attaches and rustfmt formats on save

### Requirement: Markdown language pack
The configuration SHALL provide a markdown pack with marksman LSP, markdownlint + prettier formatting, markdownlint linting, markdown-preview.nvim (with `<leader>-m` preview keymap group), markdown-toc.nvim, and an emoji completion source (blink-emoji) active in markdown and gitcommit buffers.

#### Scenario: Preview keymap
- **WHEN** the user presses `<leader>-mm` in a markdown buffer
- **THEN** a browser preview of the document opens

#### Scenario: Emoji completion
- **WHEN** the user types `:smi` in a markdown buffer with the completion menu open
- **THEN** emoji candidates appear from the emoji source

### Requirement: LaTeX language pack
The configuration SHALL provide a latex pack with texlab LSP, tex-fmt formatting, the latex treesitter parser, vimtex (quickfix mode off; WSL uses a SumatraPDF forward-search viewer, non-WSL uses zathura), and wrapping.nvim for soft-wrap editing.

#### Scenario: LaTeX editing
- **WHEN** a `.tex` file is opened
- **THEN** texlab attaches and vimtex commands (e.g. `:VimtexCompile`) are available

### Requirement: SQL language pack
The configuration SHALL provide a sql pack with sql_formatter formatting, vim-dadbod + vim-dadbod-ui + vim-dadbod-completion, a `<leader>D` database keymap group (toggle UI, add connection, find buffer), buffer-local mappings in dbui/dbout/sql buffers replicating the old config's Plug mappings (open, delete, execute query, save query, jump to foreign key, toggle layout), and a dadbod completion source for sql/mysql/plsql filetypes.

#### Scenario: Database UI
- **WHEN** the user presses `<leader>DD`
- **THEN** the DBUI drawer toggles, and in the drawer `o`/`<cr>` opens the selected item

#### Scenario: SQL completion
- **WHEN** the user edits a SQL buffer connected to a database
- **THEN** the completion menu offers dadbod-sourced table/column candidates

### Requirement: HTTP client language pack
The configuration SHALL provide an http pack with the http treesitter parser, kulala-fmt formatting, and kulala.nvim with request keymaps available in http/rest buffers: send request (`<leader>hr`), send all (`<leader>ha`), view stats (`<leader>hv`), copy as cURL (`<leader>hc`), select environment (`<leader>he`), and jump previous/next (`<leader>hp`/`<leader>hn`).

#### Scenario: Execute request
- **WHEN** the cursor is on a request in a `.http` file and the user presses `<leader>hr`
- **THEN** kulala executes the request and shows the response in a split

### Requirement: Java language pack
The configuration SHALL provide a java pack with jdtls (java-debug-adapter bundles wired into `init_options`), google-java-format formatting, checkstyle linting, the nvim-jdtls plugin, DAP configurations (launch current file, launch with main-class prompt, attach to remote JVM), a neotest-java adapter, and a `:Java` user command with subcommands build, clean, test, run, runArguments, organize, extractVariable, extractMethod, extractConstant, doc, and reloadProject — build subcommands detect maven/gradle(w) and run through Overseer.

#### Scenario: Java project build
- **WHEN** the user runs `:Java build` in a project containing `pom.xml`
- **THEN** `mvn build` runs as an Overseer task with the task list opened

#### Scenario: jdtls attach
- **WHEN** a `.java` file is opened
- **THEN** jdtls attaches with the debug bundles loaded, enabling DAP launch configurations

### Requirement: Kotlin language pack
The configuration SHALL provide a kotlin pack with kotlin_language_server (run under a SDKMAN-provided Java 21 when found, with a warning naming the `sdk install` command when not), ktlint formatting and linting, the kotlin treesitter parser, kotlin-debug-adapter DAP (launch main class, attach remote JVM), a neotest-java adapter, and a `:Kotlin` user command (build, clean, test, run, runArguments) running detected gradle(w)/maven through Overseer.

#### Scenario: KLS under Java 21
- **WHEN** a `.kt` file is opened on a machine with SDKMAN Java 21 installed
- **THEN** kotlin_language_server starts with `JAVA_HOME` pointing at the Java 21 installation

### Requirement: Dotnet language pack
The configuration SHALL provide a dotnet pack with the roslyn LSP via roslyn.nvim, easy-dotnet.nvim (its builtin LSP disabled), csharpier formatting invoked with `--stdin-path $FILENAME`, the c_sharp treesitter parser, netcoredbg DAP adapters (`coreclr` and `netcoredbg`) with launch/attach/launch-with-args configurations that locate the project dll via csproj + highest `net*` bin folder, a neotest-dotnet adapter, an easy-dotnet completion source, `SolutionSelect` and `SolutionAutoSelect` user commands, automatic upward solution selection on `.cs` BufEnter (toggleable), and a `<leader>-s` solution keymap group.

#### Scenario: Solution auto-select
- **WHEN** a `.cs` file inside a solution is opened with auto-select enabled
- **THEN** the nearest solution file found searching upward is selected via easy-dotnet

#### Scenario: Debug a console app
- **WHEN** the user starts the "Launch - netcoredbg" DAP configuration in a built project
- **THEN** the debugger launches the project's dll resolved from `bin/Debug/net*/`

### Requirement: Enriched python pack
The python pack SHALL keep basedpyright and ruff as LSP servers and additionally provide: mypy linting alongside ruff; ruff formatting extended with `ruff_organize_imports` and `ruff_fix`; venv-selector.nvim with a `<leader>-pp` picker whose selected environment activates in new terminals (falling back to the `./.venv`/`./venv` convention when nothing is selected); pymple.nvim for import management; vim-python-pep8-indent; and a neotest-python adapter using pytest.

#### Scenario: Venv selection drives terminals
- **WHEN** the user selects a virtualenv via `<leader>-pp` and opens a new toggleterm terminal
- **THEN** the terminal sources that virtualenv's activate script

#### Scenario: Dual linting
- **WHEN** a Python file with a type error and a lint violation is saved
- **THEN** both mypy and ruff diagnostics appear
