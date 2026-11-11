# Spec Delta

## Purpose

Measures where editor time goes during a real working session (hot autocmds, LSP traffic, spawned processes and per-module Lua time) so configuration changes can be compared with numbers.

## ADDED Requirements

### Requirement: Opt-in session profiler
The configuration SHALL provide a runtime profiler that is active only when Neovim starts with the environment variable `NVIM_PROFILE=1`. When the variable is unset, the profiler SHALL install no hooks, wrappers, autocmds or timers, and SHALL define no profiling commands.

#### Scenario: Disabled by default
- **WHEN** Neovim starts without `NVIM_PROFILE` set
- **THEN** `:ProfileReport` is not a command and no profiler code has run

#### Scenario: Enabled for a session
- **WHEN** Neovim starts with `NVIM_PROFILE=1`
- **THEN** the profiling commands exist and measurement starts before any plugin is set up

### Requirement: Autocmd cost by event and group
While enabled, the profiler SHALL measure every Lua-callback autocmd created after it starts, reporting per event and augroup the number of runs, total time and slowest single run.

#### Scenario: Hot handler is visible
- **WHEN** the user moves the cursor for a while in a code buffer and opens the report
- **THEN** the report lists the `CursorMoved` handlers by augroup with their run counts and total milliseconds, slowest first

### Requirement: LSP traffic by client and method
While enabled, the profiler SHALL count LSP requests per client and method and measure the time from request to response, including requests that were cancelled.

#### Scenario: Cursor-driven requests counted
- **WHEN** a server is attached and the user moves through a file
- **THEN** the report lists methods such as `textDocument/documentHighlight` and `textDocument/codeAction` with request counts and average response time per client

### Requirement: Spawned processes by command
While enabled, the profiler SHALL count external processes started by the editor (through `vim.system`, `jobstart` or libuv spawn) per executable, with their total wall-clock runtime.

#### Scenario: Linter runs counted
- **WHEN** the user leaves insert mode ten times in a Python buffer with mypy configured
- **THEN** the report shows the number of `mypy` processes started and their total runtime

### Requirement: Lua time by module
While enabled, the profiler SHALL sample Lua execution and attribute time to the plugin or configuration module whose code was running, so that work outside autocmds (decoration providers, timers, scheduled callbacks) is also measured.

#### Scenario: Decoration provider cost visible
- **WHEN** the user scrolls through a long file with indent guides and rainbow brackets enabled
- **THEN** the report attributes sampled time to those plugins by name

### Requirement: Report, snapshot and reset
`:ProfileReport` SHALL open the current measurements in a read-only scratch buffer, including session facts (uptime, loaded and listed buffers, runtimepath entries, Lua memory), and SHALL save the same data as a JSON snapshot under `stdpath("state")/profile/`. `:ProfileReset` SHALL clear all counters without restarting.

#### Scenario: Snapshot written
- **WHEN** the user runs `:ProfileReport`
- **THEN** the report buffer opens and a timestamped JSON snapshot exists in `stdpath("state")/profile/`

#### Scenario: Reset starts a clean window
- **WHEN** the user runs `:ProfileReset` and then `:ProfileReport` immediately
- **THEN** every counter in the report is zero and uptime counts from the reset

### Requirement: Snapshot comparison
`:ProfileCompare` SHALL let the user pick two saved snapshots and show their measurements side by side, normalised per hour of session uptime, with the difference for each row.

#### Scenario: Baseline against a new session
- **WHEN** the user compares the committed baseline snapshot with a snapshot from a later configuration
- **THEN** each event, method, process and module row shows both per-hour values and their difference
