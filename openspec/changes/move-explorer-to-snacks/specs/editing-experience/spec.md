# Spec Delta

## ADDED Requirements

### Requirement: Pending changes marked in the explorer
The sidebar explorer SHALL mark every file with pending agent changes, and every collapsed directory that contains one, with a review icon (`󰚩`) next to the explorer's own git and diagnostic marks, in the `AgentdiffTreeFile` / `AgentdiffTreeDir` colours. The marks SHALL update when pending changes change, without the user refreshing the explorer.

#### Scenario: Agent edits a file
- **WHEN** the explorer shows `src/` collapsed and an agent edits `src/main.lua`
- **THEN** `src/` shows the review icon, and expanding it shows the icon on `main.lua` and no longer on `src/`

#### Scenario: Marks clear after review
- **WHEN** the user keeps or undoes every change of `src/main.lua`
- **THEN** the icon disappears from `main.lua` and from `src/`

## REMOVED Requirements

### Requirement: Pending changes marked in neo-tree
**Reason**: The explorer moves from neo-tree to the snacks explorer.
**Migration**: Same marks and colours: see "Pending changes marked in the explorer".
