# Spec Delta

## MODIFIED Requirements

### Requirement: Test navigation and watch keymaps
The `<leader>t` group SHALL also provide a navigation subgroup `tn*` (next/previous test, next/previous failed) plus `]T`/`[T` motions (next/previous failed test), and a watch subgroup `tw*` (nearest/file/all). `]t`/`[t` SHALL NOT be test motions; they belong to TODO-comment navigation.

#### Scenario: Jump to next failed test
- **WHEN** a test file has failed tests and the user presses `]T`
- **THEN** the cursor moves to the next failed test

#### Scenario: Next test from the leader tree
- **WHEN** the cursor is above two tests and the user presses `<leader>tnn`
- **THEN** the cursor moves to the first of them
