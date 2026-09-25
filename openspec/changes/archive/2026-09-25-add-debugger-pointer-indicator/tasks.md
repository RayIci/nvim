# Tasks

## 1. Debugger Pointer Presentation

- [x] 1.1 Update `lua/plugins/dap.lua` to define a dedicated `DapStopped` sign with a right-arrow glyph and a dedicated, theme-overridable stopped-line highlight group; verify `:sign list DapStopped` shows the arrow and the highlight group has a distinct background.
- [x] 1.2 Configure the stopped sign to use the dedicated line highlight without changing the existing breakpoint, conditional-breakpoint, or logpoint sign definitions; verify a stopped line can show the pointer alongside an existing breakpoint.

## 2. Stopped-Location Lifecycle

- [x] 2.1 Configure nvim-dap's existing stopped-event handling to render the stopped-location indicator with the dedicated sign and highlight; verify nvim-dap moves the per-session indicator when stepping changes the current frame.
- [x] 2.2 Rely on nvim-dap's existing per-session cleanup on resume, termination, exit, and unavailable source locations; verify it removes the stopped-location sign and associated line highlight.
- [x] 2.3 Preserve nvim-dap's per-session sign groups so cleanup remains safe for unloaded buffers and parallel debug sessions without clearing unrelated signs, diagnostics, or virtual text; verify the stopped indicator coexists with these editor indicators.

## 3. Configuration Validation

- [x] 3.1 Validate the updated Lua configuration loads without errors using the repository's available headless Neovim configuration check, and verify a headless debugpy session displays and clears the pointer as specified.
