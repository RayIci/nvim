# testing Delta

## ADDED Requirements

### Requirement: Neotest test running
The configuration SHALL provide test running via neotest, set up as a subsystem module (`plugins/neotest.lua`) following the setup/apply pattern: `setup()` registers keymaps, `apply()` receives adapter-factory functions collected from language packs, resolves them (a factory MAY return one adapter or a list), and calls `neotest.setup()` with the resolved adapters, the Overseer consumer, rounded floating windows, and the old config's summary-panel mappings and status icons.

#### Scenario: Adapter from a language pack
- **WHEN** a language pack declares a `test` factory returning a neotest adapter and Neovim restarts
- **THEN** running the nearest test in that language's buffer executes through that adapter

#### Scenario: No adapters
- **WHEN** no language pack declares a `test` field
- **THEN** neotest still sets up without error and the keymaps remain defined

### Requirement: Test keymaps
The configuration SHALL provide a which-key `<leader>t` test group replicating the old config: run subcommands (`tr` nearest, `tf` file, `ta` all, `tl` last, `tS` stop, `tA` attach), debug subgroup `td*` (nearest/file/last with the DAP strategy), output subgroup `to*` (show output, toggle/open/close/clear panel), `ts` summary toggle, navigation subgroup `tn*` plus `]t`/`[t`/`]T`/`[T` motions (next/previous test, next/previous failed), watch subgroup `tw*` (nearest/file/all), `ti` status, and `tD` diagnostics. Neotest output and summary buffers SHALL close with `q`.

#### Scenario: Run nearest test
- **WHEN** the cursor is inside a test function and the user presses `<leader>tr`
- **THEN** neotest runs that test and marks its status in the sign column

#### Scenario: Debug nearest test
- **WHEN** the user presses `<leader>tdd` inside a test in a language whose adapter supports DAP
- **THEN** the test runs under the debugger and breakpoints are hit

#### Scenario: Close output with q
- **WHEN** a neotest output window is focused and the user presses `q`
- **THEN** the window closes
