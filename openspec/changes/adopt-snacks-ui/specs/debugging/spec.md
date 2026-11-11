# Spec Delta

## MODIFIED Requirements

### Requirement: Completion in DAP buffers
blink.cmp SHALL complete in DAP buffers (`dap-repl`, dapui watches/hover) through cmp-dap via blink.compat, preserving completion-item kinds (method, function, field…) in the menu. blink's prompt-buftype exclusion SHALL be lifted only for DAP buffers, so other prompt and picker input buffers stay completion-free. cmp-dap's trigger characters SHALL be guarded against sessionless calls and always include `.` (old-config nilguard).

#### Scenario: Adapter completions in the REPL
- **WHEN** the user types an object name followed by `.` in the REPL during a debug session
- **THEN** blink's menu (kind icons included) offers the adapter's member completions without covering the prompt line

#### Scenario: Prompt buffers outside DAP stay completion-free
- **WHEN** the user types in a picker's search input
- **THEN** no blink completion menu appears
