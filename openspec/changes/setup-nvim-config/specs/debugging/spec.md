## ADDED Requirements

### Requirement: Debugging via nvim-dap and dap-ui
The configuration SHALL provide debugging with nvim-dap and nvim-dap-ui, where adapters and per-language debug configurations are registered exclusively by language packs' `dap` functions. Keymaps SHALL cover breakpoint toggle, conditional breakpoint, continue/start, step over/into/out, and terminate, under a `<leader>d` which-key group.

#### Scenario: Breakpoint session
- **WHEN** the user toggles a breakpoint in a Python file and starts a debug session
- **THEN** debugpy launches, execution stops at the breakpoint, and dap-ui opens showing scopes and stack

#### Scenario: UI auto open/close
- **WHEN** a debug session starts or terminates
- **THEN** dap-ui opens automatically on start and closes on terminate

### Requirement: VSCode launch.json support
The configuration SHALL load debug configurations from the project's `.vscode/launch.json` via `dap.ext.vscode`, mapping VSCode adapter type names to registered nvim-dap adapters.

#### Scenario: Launch from launch.json
- **WHEN** a project contains `.vscode/launch.json` with a configuration for a registered adapter and the user starts a debug session
- **THEN** that configuration appears in the session picker and launches correctly

### Requirement: VSCode task runner with debug integration
The configuration SHALL run tasks via overseer.nvim, including tasks defined in the project's `.vscode/tasks.json`, and SHALL execute a launch configuration's `preLaunchTask` before starting the debug session.

#### Scenario: Run a tasks.json task
- **WHEN** the user opens the task picker in a project with `.vscode/tasks.json`
- **THEN** those tasks are listed and selecting one runs it with visible output

#### Scenario: preLaunchTask before debug
- **WHEN** a launch.json configuration declares a `preLaunchTask` and the user starts that debug session
- **THEN** the task runs to completion first and the debug session starts afterwards

### Requirement: Plugin-free breakpoint persistence
The configuration SHALL persist DAP breakpoints (line, condition, log message) per project in a custom workspace-state module — no third-party persistence plugin — restoring them both per file when a file is reopened and wholesale when a session is restored.

#### Scenario: Breakpoints survive file reopen
- **WHEN** the user sets breakpoints in a file, closes Neovim, reopens Neovim in the same project, and opens that file
- **THEN** the breakpoints reappear at their lines with conditions intact

#### Scenario: Breakpoints survive session restore
- **WHEN** the user restores the project session
- **THEN** all persisted breakpoints across files are registered with nvim-dap
