# editing-experience Delta

## ADDED Requirements

### Requirement: CopilotChat window behavior
The CopilotChat window SHALL NOT close on `<C-c>` from insert mode (`mappings.close.insert` disabled), SHALL close on `q` in normal mode, and SHALL render diffs as full diffs (`mappings.show_diffs.full_diff = true`). Existing `<leader>a*` chat keymaps and the commit-message generation flow are unchanged.

#### Scenario: Ctrl-C in the chat prompt
- **WHEN** the user is typing in the CopilotChat window in insert mode and presses `<C-c>`
- **THEN** insert mode exits but the chat window stays open

#### Scenario: Close from normal mode
- **WHEN** the user presses `q` in the CopilotChat window in normal mode
- **THEN** the chat window closes
