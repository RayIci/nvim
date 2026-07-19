# debugging Specification

## Purpose
TBD - created by syncing change setup-nvim-config. Update Purpose after archive.

## Requirements

### Requirement: Debugging via nvim-dap and dap-ui
The configuration SHALL provide debugging with nvim-dap and nvim-dap-ui, where adapters and per-language debug configurations are registered exclusively by language packs' `dap` functions. Keymaps SHALL follow the old-config scheme under a `<leader>d` which-key group with named subgroups: session control (`dc` continue saving all buffers first, `dR` restart, `dp` pause, `dC` run to cursor, `dq` terminate, `dQ` force close with dap-terminal cleanup, `dN` new parallel session), breakpoints (`dbb`/`dd`/`<leader>B` toggle, `dbB` conditional via input prompt, `dbl` logpoint, `dbc` clear all, `dbs` list), stepping (`dsi` into, `dso` over, `dsO` out, `dsb` back), floating UI elements (`dw*`: repl, console, scopes, breakpoints, stacks, watches), UI control (`duu` toggle, `duo` open, `duc` close, `dur` reset layout), REPL (`dro` open, `drc` close, `drr` toggle, `drl` run last), multi-session (`dSs` switch picker, `dSw` widget, `dSn`/`dSp` focus next/previous), launch (`dll` run last, `dlc` pick configuration, `dln` new parallel session), and evaluation (`de` eval in normal+visual, `dE` custom expression, `dh` hover widgets). Function keys SHALL mirror the primary flow: `<F5>` continue (saving all buffers first), `<F9>` step into, `<F10>` step over, `<F11>` step out. dap-ui SHALL NOT open automatically when a session starts — it opens only via its keymaps — and SHALL close automatically when the session terminates or exits.

#### Scenario: Breakpoint session
- **WHEN** the user toggles a breakpoint in a Python file and presses `<F5>`
- **THEN** modified buffers are saved, debugpy launches, and execution stops at the breakpoint without dap-ui opening on its own

#### Scenario: Manual UI toggle
- **WHEN** a debug session is running and the user presses `<leader>duu`
- **THEN** dap-ui opens; pressing it again closes it; when the session terminates any open dap-ui closes automatically

#### Scenario: FN stepping
- **WHEN** execution is stopped at a breakpoint
- **THEN** `<F10>` steps over, `<F9>` steps into, and `<F11>` steps out

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

### Requirement: Inline variable values with persisted toggle
The configuration SHALL show variable values as end-of-line virtual text during debug sessions via nvim-dap-virtual-text, and SHALL provide a toggle keymap (`<leader>dv`) whose state persists across restarts through the prefs module, applying immediately when flipped.

#### Scenario: Values inline while stopped
- **WHEN** a debug session is stopped at a breakpoint with virtual text enabled
- **THEN** variables in scope show their current values as virtual text at the end of their lines

#### Scenario: Toggle persists
- **WHEN** the user disables debug virtual text with `<leader>dv` and restarts Neovim
- **THEN** virtual text stays disabled in the next debug session until toggled back on

### Requirement: REPL clear and syntax highlighting
The DAP REPL SHALL support clearing its contents via a keymap (`<leader>drx`) and SHALL render entered expressions with treesitter syntax highlighting via nvim-dap-repl-highlights (`dap_repl` parser installed through nvim-treesitter, registered before parser installation). blink.cmp SHALL complete in DAP buffers (`dap-repl`, dapui watches/hover) through cmp-dap via blink.compat — preserving completion-item kinds (method, function, field…) in the menu — with blink's prompt-buftype exclusion lifted only for DAP buffers (other prompt buffers such as telescope's stay completion-free). cmp-dap's trigger characters SHALL be guarded against sessionless calls and always include `.` (old-config nilguard).

#### Scenario: Adapter completions in the REPL
- **WHEN** the user types an object name followed by `.` in the REPL during a debug session
- **THEN** blink's menu (kind icons included) offers the adapter's member completions without covering the prompt line

#### Scenario: Clear the REPL
- **WHEN** the REPL contains output and the user presses `<leader>drx`
- **THEN** the REPL buffer is emptied

#### Scenario: Highlighted REPL input
- **WHEN** the user types an expression in the REPL during a debug session
- **THEN** the expression renders with syntax highlighting for the session's language

### Requirement: Breakpoints persist at mutation time
Breakpoint persistence SHALL NOT depend on exit hooks: every mutating operation on dap.breakpoints (set, remove, remove_by_id, toggle, clear — from keymaps, dap-ui, or the API) SHALL schedule a debounced write of the per-project state file, so breakpoints survive `:restart`, crashes, and process kills. The VimLeavePre write remains only as a backstop.

#### Scenario: Survives :restart
- **WHEN** the user adds a breakpoint and immediately runs `:restart`
- **THEN** the breakpoint reappears in the restarted instance when the file is reopened

#### Scenario: Removal survives hard exit
- **WHEN** the user removes a breakpoint and the process is killed without VimLeavePre firing
- **THEN** the removed breakpoint does not reappear on the next start
