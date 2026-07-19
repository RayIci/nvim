# git-integration Delta

## MODIFIED Requirements

### Requirement: Copilot-generated commit messages
When a gitcommit buffer opens with no message yet (fresh commit), the configuration SHALL automatically generate a conventional commit title and description from the staged diff via CopilotChat.nvim in headless mode (no chat window) and insert it at the top of the buffer, once per buffer. Buffers arriving with an existing message (amend/reword) SHALL NOT trigger generation. A buffer-local keymap SHALL allow manual (re)generation.

#### Scenario: Automatic message on fresh commit
- **WHEN** the user runs `git commit` with staged changes and the commit buffer opens empty
- **THEN** a generated title and description are inserted into the buffer without any chat window opening, ready to edit before saving

#### Scenario: Amend untouched
- **WHEN** the user runs `git commit --amend` and the buffer opens with the previous message
- **THEN** no automatic generation happens

#### Scenario: Manual regeneration
- **WHEN** the user presses the generate keymap in a commit buffer
- **THEN** a fresh message is generated headlessly and inserted
