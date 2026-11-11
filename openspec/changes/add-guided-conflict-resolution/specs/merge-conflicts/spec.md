# Spec Delta

## Purpose

Helps the user understand and resolve git conflicts: which side is their own work and which is incoming, what the result will be, and what to do next, named by role rather than git's ours/theirs.

## ADDED Requirements

### Requirement: Operation and role detection
While a merge, rebase, cherry-pick, revert or conflicting stash apply is in progress, the configuration SHALL know the operation, its progress where git provides it, and for each conflict which side is **yours** (the work of the branch you are on) and which is **incoming** (what the operation brings in), each with its branch or commit name and subject.

#### Scenario: Merge roles
- **WHEN** the user is on `feature` and `git merge main` stops on a conflict
- **THEN** yours is `feature` and incoming is `main`

#### Scenario: Rebase roles
- **WHEN** the user is on `feature` and `git rebase main` stops while replaying commit `a1b2c3 "fix login"`
- **THEN** yours is commit `a1b2c3 "fix login"` of `feature`, incoming is `main`, and the progress reads which commit of how many is being replayed

#### Scenario: Cherry-pick roles
- **WHEN** `git cherry-pick d4e5f6` stops on a conflict on branch `release`
- **THEN** yours is `release` and incoming is commit `d4e5f6` with its subject

### Requirement: Role labels instead of ours and theirs
Every label, key description and message about a conflict SHALL name sides as YOURS and INCOMING with their branch or commit names. The words "ours", "theirs", "current" and "incoming changes" in git's sense SHALL appear only in the explain panel, which maps them to the roles for the current operation.

#### Scenario: Rebase labels are not swapped
- **WHEN** a rebase of `feature` onto `main` stops on a conflict and the user opens the file
- **THEN** the block containing the user's own commit's lines is labelled `YOURS · feature …` and the block from `main` is labelled `INCOMING · main …`, although git's markers call them the other way round

#### Scenario: Explain panel maps git terms
- **WHEN** the user presses `<leader>gC?` during that rebase
- **THEN** a panel states that git calls `main` "ours" and the user's commit "theirs" here, and lists the resolution keys

### Requirement: Inline conflict marking
A file with conflict markers SHALL show each conflict's two sides (and the common-ancestor section when the markers include one) with distinct highlights and a role label on each marker line, without the user running any command. Files without markers SHALL get no conflict highlighting.

#### Scenario: Open a conflicted file
- **WHEN** a merge leaves `src/auth.lua` with two conflicts and the user opens it
- **THEN** both conflicts show highlighted YOURS and INCOMING sections with labels, and `]x`/`[x` jump between them

### Requirement: Inline resolution keys
In a conflicted buffer, with the cursor in a conflict: `<leader>gCo` SHALL keep yours, `<leader>gCt` take incoming, `<leader>gCb` keep both with yours first, `<leader>gCB` keep both with incoming first, and `<leader>gC0` keep neither, removing the markers. `<leader>gCn`/`<leader>gCp` and `]x`/`[x` SHALL move to the next/previous conflict. `<leader>gCQ` and `<leader>gCq` SHALL list the file's conflicts in quickfix and in Trouble. Key descriptions SHALL name the branch each key keeps.

#### Scenario: Keep yours during a rebase
- **WHEN** during a rebase of `feature` onto `main` the cursor is in a conflict and the user presses `<leader>gCo`
- **THEN** the conflict is replaced by the lines from the user's own commit (the side git marks as "theirs")

#### Scenario: Descriptions name the branches
- **WHEN** the user presses `<leader>gC` in a conflicted buffer during a merge of `main` into `feature`
- **THEN** which-key shows `o` as "Keep yours (feature)" and `t` as "Take incoming (main)"

### Requirement: Resolve view with result preview
`<leader>gCr` SHALL open a resolve view for the conflict under the cursor (or the file's first conflict) showing the YOURS lines, the INCOMING lines, and a RESULT pane previewing the file around the conflict as it will be after applying the current choice. Each result line SHALL be coloured by the side it came from, and the preview SHALL update with every choice.

#### Scenario: Preview before applying
- **WHEN** the user opens the resolve view and presses `t`
- **THEN** the RESULT pane shows the surrounding code with the incoming lines in place of the conflict, and the file itself is unchanged until the user applies

### Requirement: Single-key choices in the resolve view
Inside the resolve view, `o`, `t`, `b`, `B` and `x` SHALL choose yours, incoming, both (yours first), both (incoming first) and neither. `<CR>` SHALL apply the choice to the file and move to the next conflict, `n`/`p` move between conflicts without applying, `u` undo the last apply, `?` open the explain panel and `q` close.

#### Scenario: Resolve a file conflict by conflict
- **WHEN** a file has three conflicts and the user, in the resolve view, presses `o` `<CR>` `t` `<CR>` `b` `<CR>`
- **THEN** the file has no conflict markers, its three regions hold yours, incoming and both respectively, and the view reports the file resolved

#### Scenario: Undo an apply
- **WHEN** the user applies a choice and then presses `u`
- **THEN** that conflict returns to the file with its markers and the view shows it again

### Requirement: Keeping portions of both sides
In the resolve view, `<Space>` SHALL keep or drop the line under the cursor, or every line of a visual selection, in either side's pane, and `J`/`K` SHALL move a kept line down or up in the result. `e` SHALL let the user edit the result text directly before applying.

#### Scenario: Mix lines from both sides
- **WHEN** yours has lines A1, A2 and incoming has lines B1, B2, and the user keeps A1 and B2 with `<Space>`, moves B2 above A1 with `K`, and presses `<CR>`
- **THEN** the conflict in the file is replaced by B2 followed by A1

#### Scenario: Hand edit
- **WHEN** the user chooses both, presses `e`, changes a line in the result and applies
- **THEN** the file contains the edited result in place of the conflict

### Requirement: Conflict center
`<leader>gCC` SHALL open a panel stating the operation in plain words (for example "REBASING feature onto main, commit 2 of 5"), which branch or commit is yours and which is incoming, and every conflicted file with its remaining conflict count. From the panel the user SHALL be able to open a file in the resolve view, open the whole-file 3-way view, stage a resolved file, continue, skip (during a rebase) and abort.

#### Scenario: Overview during a merge
- **WHEN** a merge of `main` into `feature` left `a.lua` with 2 conflicts and `b.lua` with 1, and the user presses `<leader>gCC`
- **THEN** the panel reads "MERGING main into feature", names the sides, and lists `a.lua (2)` and `b.lua (1)`

#### Scenario: No operation
- **WHEN** no merge, rebase, cherry-pick, revert or stash conflict is in progress and the user presses `<leader>gCC`
- **THEN** a notification says there is nothing to resolve

### Requirement: Next-step commands
`<leader>gCm` SHALL open the whole-file 3-way view, `<leader>gCa` stage the current file, `<leader>gCc` continue the operation, and `<leader>gCA` abort it after a confirmation. Staging SHALL be refused while the file still has markers, and continuing SHALL be refused while any file is unresolved, each with a message saying what remains.

#### Scenario: Stage refused with markers
- **WHEN** the current file still has one conflict and the user presses `<leader>gCa`
- **THEN** the file is not staged and a message says one conflict remains in it

#### Scenario: Continue after resolving
- **WHEN** all conflicted files are resolved and staged during a rebase and the user presses `<leader>gCc`
- **THEN** the rebase continues with git's default message, and the statusline shows the next commit or nothing when the rebase is finished

#### Scenario: Abort asks first
- **WHEN** the user presses `<leader>gCA` and declines the confirmation
- **THEN** the operation is still in progress and no file changed

### Requirement: Guidance and status
When the last conflict of a file is resolved, a notification SHALL suggest staging it with `<leader>gCa`. When no conflicted file remains, a notification SHALL suggest continuing with `<leader>gCc`. While an operation is in progress, the statusline SHALL show its kind, its progress where known, and the number of conflicted files, and show nothing otherwise.

#### Scenario: Status during a rebase
- **WHEN** a rebase is on commit 2 of 5 with 3 conflicted files
- **THEN** the statusline shows `⚔ REBASE 2/5 · 3 files`

#### Scenario: Suggest the next step
- **WHEN** the user resolves the last conflict of the last conflicted file
- **THEN** a notification suggests `<leader>gCa` for the file and, once it is staged, `<leader>gCc` to continue

### Requirement: No conflict work outside operations
The configuration SHALL NOT run git commands or scan buffers for conflicts while no merge, rebase, cherry-pick, revert or stash conflict is in progress, beyond checking for the repository's operation-state files when Neovim gains focus, changes directory, or after its own git actions.

#### Scenario: Normal editing stays quiet
- **WHEN** no operation is in progress and the user edits and switches buffers for a while
- **THEN** no git process is started by the conflict module
