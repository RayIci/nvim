# Proposal

## Why

While debugging in Neovim, it is difficult to identify the exact source line where execution is currently stopped. Adding both a right-arrow sign and a distinct line background will make the active debugger location immediately visible and make stepping through code easier to follow.

## What Changes

- Display a right-arrow sign beside the source line where the debugger is currently stopped.
- Highlight the complete stopped source line with a distinct background color.
- Update the arrow and line highlight as execution moves between source lines.
- Remove the stopped-line indicators when execution resumes or the debug session ends.
- Keep the indicators compatible with existing breakpoints, diagnostics, virtual text, and other sign-column or line highlights.

## Capabilities

### New Capabilities

- `debugger-pointer-indicator`: Visual indicators for the source location where nvim-dap execution is stopped.

### Modified Capabilities

- `debugging`: Extend the debugging experience to require a visible current-execution arrow and line highlight while execution is stopped, with cleanup when execution is no longer stopped.

## Impact

- Affects the nvim-dap integration and debug-session event handling.
- Adds or updates Neovim sign and highlight definitions used by the debugging configuration.
- May interact with existing breakpoint signs, diagnostics, and user theme colors, but should not change breakpoint persistence or debug keymaps.
