## ADDED Requirements

### Requirement: Larger Trouble symbols outline
The Trouble document symbols outline SHALL open as a right-side split sized to 35% of the editor width, and all configured symbols-outline entry points SHALL use that same size.

#### Scenario: Symbols outline width
- **WHEN** the user opens the Trouble symbols outline from any configured symbols keymap
- **THEN** the outline opens on the right at 35% of the editor width

#### Scenario: Other Trouble modes unchanged
- **WHEN** the user opens Trouble diagnostics, quickfix, loclist, or LSP defs/refs panels
- **THEN** those modes keep their existing layout behavior unless explicitly configured otherwise
