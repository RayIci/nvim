# editing-experience Delta

## MODIFIED Requirements

### Requirement: Signature help while completing
The configuration SHALL show function signature help (active parameter highlighted) automatically while typing call arguments, rendered by exactly one provider: blink.cmp's signature window. No other plugin (noice or otherwise) SHALL open a second signature window for the same trigger.

#### Scenario: Signature popup
- **WHEN** the user types `(` after a function name with an attached LSP
- **THEN** a single signature window appears highlighting the current parameter as the user types

#### Scenario: No duplicate window
- **WHEN** signature help triggers during completion of a function call
- **THEN** exactly one floating signature window is visible

## ADDED Requirements

### Requirement: Rendered markdown in completion windows
blink.cmp's documentation and signature buffers SHALL render formatted markdown via render-markdown.nvim (their filetypes registered as markdown for treesitter), and the rendering SHALL stay correct while cycling candidates: because blink reuses the same buffer, a buffer-attach listener SHALL re-render on content change.

#### Scenario: Formatted docs on first open
- **WHEN** the completion documentation window opens for a candidate whose docs contain headings, emphasis, and code fences
- **THEN** the window shows rendered markdown (styled headings, concealed markup, highlighted code) rather than raw markup

#### Scenario: Rendering survives candidate cycling
- **WHEN** the user cycles across several completion candidates with markdown documentation
- **THEN** each candidate's documentation window remains rendered, not plain escaped markdown
