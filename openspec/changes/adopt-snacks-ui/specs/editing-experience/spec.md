# Spec Delta

## MODIFIED Requirements

### Requirement: Reference navigation
The configuration SHALL highlight other references of the symbol under the cursor, as reported by the attached language server's document highlights, and provide `]]`/`[[` next/previous-reference keymaps. Buffers without a server offering document highlights SHALL show no reference highlighting.

#### Scenario: Jump between references
- **WHEN** the cursor rests on a variable with multiple uses and the user presses `]]`
- **THEN** the cursor jumps to the next reference of that variable in the buffer

#### Scenario: Highlight follows the cursor
- **WHEN** the cursor rests on a function name in a buffer with an attached server
- **THEN** the other uses of that name in the visible buffer are highlighted, and the highlight moves with the cursor to a different symbol
