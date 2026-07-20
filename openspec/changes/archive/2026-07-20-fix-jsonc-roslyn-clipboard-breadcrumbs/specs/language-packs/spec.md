## MODIFIED Requirements

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
