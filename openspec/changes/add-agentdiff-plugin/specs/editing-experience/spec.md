# Spec Delta

## ADDED Requirements

### Requirement: Agent change review wiring
The configuration SHALL install the `agentdiff` plugin and configure it, supplying its options, keymaps, tool claims and statusline widget. The review behaviour itself is specified by the `agent-change-review` capability; this configuration owns only the wiring, and no other module SHALL contain agent change review logic.

#### Scenario: Review active after startup
- **WHEN** Neovim starts in a project and an agent in another tmux pane edits a file
- **THEN** the edit is shown as a pending change using the configured keymaps and colours

### Requirement: Agent change review keymaps
`]a`/`[a` SHALL move to the next/previous pending change across files and `]A`/`[A` to the next/previous changed file. A `<leader>r` "review" which-key group SHALL provide `rk`/`ru` keep/undo the change under the cursor (in visual mode: the selected lines), `rK`/`rU` keep/undo the file, `ra`/`rA` keep/undo all, `rr` toggle the panel, `rv` toggle side-by-side, `rh` hide/show the overlay and `rc` resolve a conflicted file.

#### Scenario: Step and keep
- **WHEN** two files have pending changes and the user presses `]a` repeatedly, pressing `<leader>rk` on each change
- **THEN** the cursor visits every change across both files and nothing is pending at the end

#### Scenario: Keep a selection
- **WHEN** the user selects two lines of a pending change in visual mode and presses `<leader>rk`
- **THEN** only those lines are kept

#### Scenario: Leader popup
- **WHEN** the user presses `<leader>`
- **THEN** which-key lists a "review" group under `r`

### Requirement: Agent review toggle keymap
`<leader>uR` SHALL toggle agent change review on and off, persisted across restarts, and SHALL be listed in the ui/toggles which-key group.

#### Scenario: Toggle review
- **WHEN** the user presses `<leader>uR` and restarts Neovim
- **THEN** review is off after the restart, and pressing `<leader>uR` again turns it back on

### Requirement: Tool writes claimed as the user's
File operations performed from Neovim by tools that write to disk directly — oil.nvim actions and grug-far replacements — SHALL be claimed as the user's, so they never appear as pending agent changes.

#### Scenario: Oil rename
- **WHEN** the user renames a file in oil and saves the oil buffer
- **THEN** neither the old nor the new path is shown as a pending change

#### Scenario: Project-wide replace
- **WHEN** the user runs a grug-far replacement across several files
- **THEN** none of the replaced files is shown as a pending change

### Requirement: Pending changes marked in neo-tree
The neo-tree file tree SHALL mark every file with pending agent changes, and every collapsed directory that contains one, with a review icon (`󰚩`) next to neo-tree's own git and diagnostic marks, in the `AgentdiffTreeFile` / `AgentdiffTreeDir` colours. The marks SHALL update when pending changes change, without the user refreshing the tree.

#### Scenario: Agent edits a file
- **WHEN** neo-tree shows `src/` collapsed and an agent edits `src/main.lua`
- **THEN** `src/` shows the review icon, and expanding it shows the icon on `main.lua`

#### Scenario: Marks clear after review
- **WHEN** the user keeps or undoes every change of `src/main.lua`
- **THEN** the icon disappears from `main.lua` and from `src/`

### Requirement: Pending changes in the statusline
The statusline SHALL show the agentdiff summary of pending changes through the statusline widget registry, with its own icon, and SHALL show nothing when no change is pending.

#### Scenario: Summary visible
- **WHEN** an agent has changed three files with seven changes
- **THEN** the statusline shows the pending summary for 3 files and 7 changes

#### Scenario: Hidden when empty
- **WHEN** every pending change has been kept or undone
- **THEN** the agentdiff widget disappears from the statusline
