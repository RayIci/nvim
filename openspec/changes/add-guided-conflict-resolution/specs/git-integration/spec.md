# Spec Delta

## REMOVED Requirements

### Requirement: Merge conflict resolution via git-conflict.nvim
**Reason**: Its sides and keys followed git's ours/theirs, which swap during a rebase, and it offered no preview, no partial resolution and no next steps. Conflict handling moves to the `merge-conflicts` capability.
**Migration**: The same `<leader>gC` keys exist and now pick by role (yours/incoming). `<leader>gCo` keeps your side and `<leader>gCt` takes the incoming side in every operation, including rebases. See `merge-conflicts` for the resolve view (`<leader>gCr`) and the conflict center (`<leader>gCC`).
