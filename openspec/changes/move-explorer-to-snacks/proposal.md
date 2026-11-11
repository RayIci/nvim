# Proposal

## Why

neo-tree is the most likely cause of the slowdown over a long session:
- `config/autocmds.lua` makes it rerun `git status` and re-render on every BufEnter, CursorHold and FocusGained, throttled to 2 s;
- every render then triggers a debounced read, walk and write of the explorer's state file in `config/workspace/explorer.lua`;
- a libuv watcher is added for every folder expanded during the day.

On top of that, neo-tree brings nui and window-picker, and needed a `:restart` foreign-buffer workaround.

The snacks explorer watches only open folders and the git index, and it comes with the snacks plugin already installed. The user wants to move to it while keeping the `Y` copy-path menu, the agentdiff review marks, and the persisted per-project explorer state.

Apply after `adopt-snacks-ui`.

## What Changes

- **The explorer.** `<leader>e` toggles the snacks explorer as a 45-column left sidebar that follows the current file and shows git and diagnostic marks. `nvim <dir>` opens it on that directory.
- **Explorer keys kept from neo-tree:**
  - `<cr>`/`w` open a file directly when there is one editing window, and otherwise ask which window;
  - `<cr>`/`w` on a directory expand or collapse it;
  - `Y` opens the copy-path chooser (filename, stem, absolute, cwd-relative, home-relative, extension);
  - `n` creates a .NET item in the directory under the cursor;
  - `H` shows or hides the hide-list entries.
- **Hide lists carried over:** hidden by name (`.git`, cache dirs, `bin`/`obj`, `node_modules`, `.next`, `.github`), hidden by pattern (venvs, `*.egg-info`), and never shown (`__pycache__`, `.conform.*`). Dotfiles and git-ignored files stay visible, as today.
- **Global keys inside the explorer:** `<C-h/j/k/l>`, `<C-s>` and `<C-t>` keep their global meaning (tmux navigation, save, toggleterm) instead of snacks' list defaults.
- **Quitting:** closing the last editing window quits Neovim even while the explorer is open.
- **Session and workspace state.** Persistence is rewritten for the snacks explorer, with the same user-visible behaviour:
  - per project, the open/closed state and the expanded folders are saved when they change;
  - they are restored with the session and on worktree switches;
  - they survive `:restart` and crashes;
  - a session in which the explorer was never opened keeps the stored folders.
- **External-change refresh:**
  - buffers still reload on focus, terminal leave, buffer enter and idle (`:checktime`, throttled as today);
  - the explorer's git marks refresh on focus gain, terminal leave, and whenever agentdiff reports new agent changes;
  - **the editor no longer runs `git status` on BufEnter or CursorHold.**
- **agentdiff.nvim** (cross-repo) gains a snacks-explorer integration: a review mark next to changed files and collapsed folders containing them, refreshed on `AgentdiffChanged`. It replaces the neo-tree integration in this configuration.
- **git-worktree.nvim** (cross-repo) gains a `snacks_explorer` integration that closes the explorer before the outgoing workspace is torn down. It replaces `neotree` in the enabled integrations.
- **Theme:** folder icons keep the theme's `FolderIcon` colour, or `#E5C07B`. vale.nvim's theme covers the explorer.
- **BREAKING (minor):** neo-tree's explorer-only keys that snacks names differently are listed in the README (for example `Z` collapses all; `P` toggles preview).

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `ui-shell`:
  - explorer requirements (toggle, file opening, hide lists, advanced yank, folder icons) move from neo-tree to the snacks explorer;
  - session restore keeps explorer state under the new provider;
  - oil's coexistence requirement names the new sidebar;
  - new requirements cover the explorer's global keys and external-change refresh.
- `editing-experience`: the pending-change marks move from neo-tree to the explorer.
- `vale-engine`: the required integrations list and its scenarios name the picker and explorer instead of telescope and neo-tree.

## Impact

- Removed: neo-tree.nvim, nvim-window-picker, `lua/plugins/neotree.lua`. nui.nvim stays: pymple.nvim (python pack) still requires it.
- New: `lua/plugins/explorer.lua`. Rewritten: `lua/config/workspace/explorer.lua`. Edited: `lua/config/autocmds.lua`, `lua/plugins/bufferline.lua` (sidebar offset), `lua/plugins/auto-session.lua` (bypass filetypes), `lua/plugins/git-worktree.lua`, `lua/plugins/agentdiff.lua`, `lua/plugins/lualine.lua` (extension list), `lua/plugins/oil.lua` (comments), `lua/config/buffers.lua` (comment), `tests/workspace.lua`, `tests/workspace-startup.lua`, `README.md`.
- Cross-repo feature branches: RayIci/agentdiff.nvim (`lua/agentdiff/integrations/snacks_explorer.lua`), RayIci/git-worktree.nvim (`lua/git-worktree/integrations/snacks_explorer.lua`), RayIci/vale.nvim (explorer groups).
- State files: the explorer state path changes from `stdpath("state")/neotree/` to `stdpath("state")/explorer/`. Existing neo-tree files are migrated once on first read (same `nodes`/`is_open` shape).
