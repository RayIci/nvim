# debugging Delta

## MODIFIED Requirements

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

## ADDED Requirements

### Requirement: Inline variable values with persisted toggle
The configuration SHALL show variable values as end-of-line virtual text during debug sessions via nvim-dap-virtual-text, and SHALL provide a toggle keymap (`<leader>dv`) whose state persists across restarts through the prefs module, applying immediately when flipped.

#### Scenario: Values inline while stopped
- **WHEN** a debug session is stopped at a breakpoint with virtual text enabled
- **THEN** variables in scope show their current values as virtual text at the end of their lines

#### Scenario: Toggle persists
- **WHEN** the user disables debug virtual text with `<leader>dv` and restarts Neovim
- **THEN** virtual text stays disabled in the next debug session until toggled back on
