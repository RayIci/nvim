# Design

## Context

The existing debugging integration already receives nvim-dap lifecycle and stop events, and it manages other editor-visible debug state such as breakpoints and virtual text. The new indicator should build on that integration without introducing a separate debugger plugin or changing session controls.

## Goals / Non-Goals

**Goals:**

- Represent the current stopped location with a dedicated sign definition and sign placement.
- Highlight the stopped line through a dedicated highlight group.
- Keep exactly one active stopped-location indicator per debug session and update it when the stopped frame changes.
- Clear all indicator state on resume, termination, exit, and session cleanup.
- Preserve existing breakpoint signs, diagnostics, and virtual text.

**Non-Goals:**

- Changing breakpoint appearance or persistence.
- Opening or reconfiguring dap-ui automatically.
- Adding a new dependency or exposing new user commands.
- Persisting the current execution location between sessions.

## Decisions

### Use nvim-dap lifecycle events as the source of truth

The integration will react to stop events to obtain the current frame and place the indicator, and to resume/termination/exit events to clear it. This avoids polling and ensures stepping updates the display only after the debugger reports its new location.

Alternative considered: polling the current frame or cursor position. This could be stale, adds timers, and would confuse the user's cursor location with the debugger's execution location.

### Use a dedicated sign and line highlight

The arrow will use a dedicated sign name and a right-arrow text glyph. The stopped line will use a separate highlight group applied with a line-level match or equivalent editor highlight mechanism. Both names will be scoped to the debugger integration so they do not overwrite breakpoint definitions.

Alternative considered: moving the user's cursor to the stopped line. This would disrupt normal navigation and cannot provide a persistent visual marker when the user inspects another buffer or window.

### Track and clear owned state explicitly

The integration will retain the buffer and line associated with the currently placed indicator, plus the sign identifier or namespace state needed for removal. Before placing a new indicator, it will remove the previous one; cleanup will remove both the sign and line highlight even if the stopped frame has no usable source location.

Alternative considered: clearing all signs or highlights in the buffer. That would damage user signs, breakpoints, and diagnostics, so cleanup will be limited to state owned by this feature.

### Use stable, theme-overridable highlight defaults

The line highlight will be defined with a named highlight group and a readable default background, while allowing colorschemes or user configuration to override it. The sign will use the same group or a compatible foreground so it remains legible in the sign column.

## Risks / Trade-offs

- [Risk] A debug adapter may report a frame without a source path or line → clear stale state and do not place a replacement indicator.
- [Risk] A buffer may be unloaded before cleanup → use buffer-local/namespace-aware removal and tolerate already-invalid buffers without affecting other signs.
- [Risk] Colorschemes may redefine highlight groups after setup → apply the default early and document the named group as user-overridable; refresh only through normal highlight setup.
- [Risk] Multiple parallel debug sessions may stop at different locations → associate indicator state with the active session and clear or replace it when the active session changes.

## Migration Plan

No migration is required. Add the indicator definitions and event handling to the existing debugging configuration. Rollback consists of removing the new sign/highlight setup and event handlers; existing debugging behavior remains unchanged.
