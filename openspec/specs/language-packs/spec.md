# language-packs Specification

## Purpose
Concrete per-language packs built on the lang-pack-framework: which LSP servers, formatters, linters, DAP adapters, plugins, and keymaps each supported language gets, and their expected end-to-end behavior.

## Requirements

### Requirement: Shell and config-file language packs
The configuration SHALL provide language packs for bash (bashls + shfmt), docker (dockerls + docker_compose_language_service), json (jsonls with schemastore.nvim schemas, prettier format, jsonlint lint), yaml (yamlls, prettier format, yamllint lint), toml (tombi LSP + tombi format), xml (lemminx + csharpier format), gradle (gradle_ls), and make (mbake format), each installing its mason tools and treesitter parsers. The json pack SHALL request only treesitter parsers that exist on nvim-treesitter's `main` branch (`json`, `json5`), and SHALL register the `json` parser for the `jsonc` filetype so jsonc files highlight without emitting an "unsupported language" warning at startup.

#### Scenario: JSON with schema
- **WHEN** a `package.json` file is opened
- **THEN** jsonls attaches with schemastore-provided schema validation, and format-on-save runs prettier

#### Scenario: Shell script
- **WHEN** a `.sh` file is opened and saved
- **THEN** bashls is attached and shfmt formats the buffer

#### Scenario: JSONC highlights without warning
- **WHEN** Neovim starts and installs treesitter parsers for the json pack
- **THEN** no `skipping unsupported language: jsonc` warning is emitted
- **AND** opening a `.jsonc` file (e.g. `tsconfig.json`, `.vscode/settings.json`) applies treesitter highlighting via the `json` parser

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
The configuration SHALL provide a dotnet pack with the roslyn LSP via roslyn.nvim, easy-dotnet.nvim (its builtin LSP disabled), csharpier formatting invoked with `--stdin-path $FILENAME`, the c_sharp treesitter parser, netcoredbg DAP adapters (`coreclr` and `netcoredbg`) with launch/attach/launch-with-args configurations that locate the project dll via csproj + highest `net*` bin folder, a neotest-dotnet adapter, an easy-dotnet completion source, `SolutionSelect` and `SolutionAutoSelect` user commands, automatic upward solution selection on `.cs` BufEnter (toggleable), and a `<leader>-s` solution keymap group. The pack SHALL declare its roslyn language server to mason under the package name `roslyn-language-server` so mason-tool-installer can resolve and install it.

#### Scenario: Roslyn tool installs cleanly
- **WHEN** Neovim starts and mason-tool-installer processes the dotnet pack's tools
- **THEN** no `Cannot find package "roslyn"` error is raised
- **AND** the `roslyn-language-server` mason package is queued for installation

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

### Requirement: Jupyter notebook language pack
The configuration SHALL provide a jupyter pack that syncs percent-format `*.ju.*` files with a JupyterLab notebook through neopyter, in direct mode with Neovim listening on `127.0.0.1:9001`. Each `*.ju.py` file SHALL map to the `.ipynb` of the same base name, created automatically if missing. Buffers attached to neopyter SHALL get buffer-local keymaps under a `<leader>-j` "Jupyter" which-key group:

- run cell (`<leader>-jr`)
- run cell and select next (`<leader>-jn`)
- run all above (`<leader>-ja`)
- run all (`<leader>-jA`)
- restart kernel (`<leader>-jk`)
- restart kernel and run all (`<leader>-jK`)
- connect (`<leader>-jc`)
- status (`<leader>-js`)
- sync buffer to notebook (`<leader>-jy`)

In notebook buffers only (`*.ju.*` files, and an `.ipynb` left open as raw JSON), whether or not neopyter is connected, `<leader>-jt` SHALL open a floating cheat sheet of JupyterLab DataFrame tools (Buckaroo, D-Tale), `<leader>-jh` SHALL open a floating cheat sheet of every supported cell syntax (code, titled code, markdown in string and comment form, raw, line and cell magics) with the run keymaps, and `<leader>-jS` SHALL show a notification with one-line uv and pip commands to set up a project for notebooks and to start JupyterLab. Python buffers SHALL offer kernel-backed completion candidates from neopyter alongside the default sources. `*.ju.*` buffers SHALL be formatted (on save and manually) with code formatting and import sorting only, never with lint autofixes, so that side-effect imports such as `import buckaroo` are never removed. Files that don't match `*.ju.*` SHALL behave exactly as they do under the python pack.

#### Scenario: Live sync to JupyterLab
- **WHEN** JupyterLab is running with the neopyter extension in direct mode on `127.0.0.1:9001` and the user opens `smoke.ju.py`
- **THEN** neopyter connects, `smoke.ipynb` is opened (created if absent) in JupyterLab, and edits to cells in Neovim appear in the notebook

#### Scenario: Notebook shows the buffer's cells after opening
- **WHEN** neopyter opens a notebook in JupyterLab whose file on disk differs from the buffer (for example, a freshly created empty `.ipynb`)
- **THEN** within a few seconds, without any edit, the notebook shows the buffer's cells instead of the on-disk content

#### Scenario: No blank edge lines in synced cells
- **WHEN** cells in a `*.ju.py` are separated by blank lines before the next `# %%`
- **THEN** the notebook's cells contain the cell text without leading or trailing blank lines, and indentation inside the cell is preserved

#### Scenario: Run cell from Neovim
- **WHEN** the cursor is inside a `# %%` cell of an attached buffer and the user presses `<leader>-jr`
- **THEN** that cell executes in the JupyterLab kernel and its output appears in the browser

#### Scenario: Restart kernel
- **WHEN** the user presses `<leader>-jk` in an attached buffer
- **THEN** the notebook's kernel restarts and previously defined names are no longer available

#### Scenario: Project setup commands
- **WHEN** the user presses `<leader>-jS` in a `*.ju.py` buffer
- **THEN** a notification shows, for both uv and pip, a setup command that installs `jupyterlab neopyter ipykernel jupytext` and a run command that starts JupyterLab

#### Scenario: DataFrame tools sheet
- **WHEN** the user presses `<leader>-jt` in a `*.ju.py` buffer
- **THEN** a read-only floating window shows how to install and use Buckaroo and D-Tale in a notebook, and `q` or `<Esc>` closes it

#### Scenario: Cell syntax sheet
- **WHEN** the user presses `<leader>-jh` in a `*.ju.py` buffer
- **THEN** a read-only floating window titled "Notebook cells" shows each cell syntax with an example, every example syncs to the intended notebook cell type, and `q` or `<Esc>` closes it

#### Scenario: Keymaps scoped to notebooks
- **WHEN** the user opens a plain `.py` file that does not match `*.ju.*`
- **THEN** no `<leader>-j` mappings exist in that buffer, including `<leader>-jS` and `<leader>-jt`

#### Scenario: Kernel completion
- **WHEN** the user types `%ti` in an attached buffer with an active connection
- **THEN** the completion menu offers magic candidates such as `%timeit` from the Neopyter source

#### Scenario: Notebook formatted on save without lint fixes
- **WHEN** a `*.ju.py` buffer with an over-long line, unsorted imports, an unused side-effect `import buckaroo` and a `# %timeit` magic is saved
- **THEN** the long line is reformatted and the imports are sorted, while `import buckaroo` and the `# %timeit` line are kept unchanged

#### Scenario: Plain Python keeps its full formatter chain
- **WHEN** a plain `.py` file with an unused import is saved
- **THEN** the python pack's full formatter chain, including lint autofixes, runs as before

### Requirement: Jupyter notebook pairing
The jupyter pack SHALL treat a `*.ju.py` file as the source of truth for the `.ipynb` of the same base name (`X.ju.py` ↔ `X.ipynb`, including dotted names such as `X.v2.ju.py` ↔ `X.v2.ipynb`). It SHALL import existing notebooks into that format with jupytext, so that neopyter syncs them back cell for cell:
- markdown cells as `"""` blocks;
- line magics as `# %magic`;
- cell magics as `# %%` followed by `# %%<magic>`;
- no header before the first cell.

The pack SHALL NOT let neopyter replace notebook cells that the `.ju.py` doesn't contain without asking the user first. When jupytext is unavailable, opening an `.ipynb` SHALL show its raw JSON and report the error.

#### Scenario: Open an existing notebook
- **WHEN** the user opens `analysis.ipynb` and no `analysis.ju.py` exists
- **THEN** `analysis.ju.py` is created from the notebook's cells and opened in its place, attached to neopyter, and no `.ipynb` buffer remains

#### Scenario: Open a new or empty notebook
- **WHEN** the user opens `scratch.ipynb` that doesn't exist yet or is 0 bytes (for example, just created from the file tree)
- **THEN** `scratch.ipynb` is written as a valid empty Python 3 notebook, and `scratch.ju.py` is created with one empty `# %%` cell, opened and attached to neopyter, with no import error

#### Scenario: Open a notebook that is already paired
- **WHEN** the user opens `analysis.ipynb` and `analysis.ju.py` exists
- **THEN** `analysis.ju.py` is opened without being regenerated

#### Scenario: New .ju.py next to an existing notebook
- **WHEN** the user creates `analysis.ju.py` while `analysis.ipynb` exists
- **THEN** the buffer starts with the notebook's cells, not empty, so the notebook isn't wiped on the first sync

#### Scenario: New .ju.py without a notebook
- **WHEN** the user creates `scratch.ju.py` and no notebook with cells exists for it
- **THEN** the buffer starts with one empty `# %%` cell and is attached to neopyter

#### Scenario: Notebook changed elsewhere
- **WHEN** `analysis.ipynb` was modified after `analysis.ju.py` and contains cell source the `.ju.py` lacks, and the user opens `analysis.ju.py`
- **THEN** the user is asked to either import the notebook (overwriting the `.ju.py`) or keep the `.ju.py` (letting neopyter overwrite the notebook), before neopyter syncs

#### Scenario: Notebook only re-saved by JupyterLab
- **WHEN** `analysis.ipynb` is newer than `analysis.ju.py` but its cell sources match, for example because only outputs changed
- **THEN** `analysis.ju.py` opens without a prompt

#### Scenario: Magics round-trip
- **WHEN** a notebook with a `%timeit` cell and a `%%bash` cell is imported and synced to JupyterLab
- **THEN** the notebook's cells contain `%timeit ...` and `%%bash` + body exactly as they did before the import
