# Spec Delta

## ADDED Requirements

### Requirement: Vale theme plugin wiring
The configuration SHALL install the `vale` theme plugin from its published repository and set up its studio commands (`:Vale`, `:Vale new`, `:Vale edit`, `:Vale stop`). The bundled `vale` theme SHALL come from the plugin. The configuration's own themes SHALL stay in its `themes/` directory, with their colorscheme and statusline loaders in its `colors/` and `lua/lualine/themes/` directories.

#### Scenario: Own theme keeps loading
- **WHEN** Neovim starts with the published plugin installed and the user runs `:colorscheme vale-starter-night`
- **THEN** the theme loads from `themes/vale-starter/` in the configuration, and the statusline uses its matching lualine theme

#### Scenario: Bundled theme from the plugin
- **WHEN** the configuration has no copy of the `vale` theme (no `themes/vale/` directory and no `vale-night`/`vale-day` loader files) and the user runs `:colorscheme vale-night`
- **THEN** the theme loads from the plugin

#### Scenario: New theme lands in the configuration
- **WHEN** the user creates theme `ocean` in the studio
- **THEN** `themes/ocean/` and its loaders are written inside the configuration directory, and nothing is written inside the plugin's install directory

#### Scenario: Editing the bundled theme never touches the install directory
- **WHEN** the user edits and saves the bundled `vale` theme in the studio
- **THEN** the saved palette lives in the configuration's `themes/` directory, and the plugin's install directory is unchanged, so a plugin update cannot overwrite the edit

## MODIFIED Requirements

### Requirement: Configuration colorschemes in the theme picker
The picker SHALL also list, at the top, every vale colorscheme: those bundled with the vale plugin (such as `vale-night` and `vale-day`) and those defined by a file in the configuration's own `colors/` directory, discovered at startup so that newly generated themes appear without editing the picker configuration. Each colorscheme SHALL be listed once. On first launch, when no selection has been persisted, `vale-night` SHALL be the active colorscheme.

#### Scenario: Vale in the picker
- **WHEN** the user opens the themery picker
- **THEN** `vale-night` and `vale-day` are listed among the configuration's own colorschemes at the top, and selecting one applies it with live preview

#### Scenario: New theme appears without config edits
- **WHEN** a new colorscheme file `colors/ocean-night.lua` is added to the configuration and Neovim restarts
- **THEN** the themery picker lists `ocean-night` at the top, with no change to `lua/plugins/theme.lua`

#### Scenario: Bundled theme copied into the configuration is listed once
- **WHEN** the configuration has its own copy of the `vale` theme and loaders, and the plugin also bundles `vale`
- **THEN** `vale-night` appears once in the picker and loads the configuration's copy

#### Scenario: First-launch default
- **WHEN** Neovim starts with no persisted themery selection
- **THEN** `vale-night` is the active colorscheme

### Requirement: Whole-workspace worktree switching
A managed worktree switch SHALL replace the whole workspace in the current Neovim instance: the configuration's enabled integrations and workspace persistence SHALL save the outgoing session and workspace state before the directory changes, then restore the destination's buffers, tabs, layout, pins, breakpoints, and explorer state. Listed buffers and per-tab membership from the outgoing workspace SHALL NOT leak into the destination.

#### Scenario: Switch between saved workspaces
- **WHEN** worktrees A and B have different open files, layouts, tab memberships, pins, breakpoints, and explorer expansion states, and the user switches from A to B
- **THEN** B's saved state is restored, A's editor state is no longer active, and switching back restores A's outgoing state

#### Scenario: Switch from any editing tab
- **WHEN** the source workspace has multiple tabs and hidden buffers
- **THEN** switching saves and replaces the entire workspace rather than changing only the active tab's directory or file

#### Scenario: Switch through the floating Git interface
- **WHEN** the user initiates switching from the configured Neogit worktree menu
- **THEN** the outgoing editing layout is saved without replacing it with the transient Git menu

#### Scenario: Select the active checkout
- **WHEN** the user selects the already active checkout
- **THEN** no session reset, directory change, or buffer teardown occurs

### Requirement: Workspace persistence isolation
The configuration's workspace persistence SHALL take part in managed transitions: it SHALL flush outgoing state under its original workspace identity before teardown and prevent transitional or stale callbacks from overwriting either workspace's saved state. Deferred restoration SHALL affect only the workspace for which it was scheduled. Existing empty snapshots SHALL be authoritative and distinct from missing snapshots.

#### Scenario: Save pending at switch time
- **WHEN** a source workspace save is pending when the user switches
- **THEN** the latest source state is saved under the source identity and the pending callback never writes it under the target identity

#### Scenario: Old restore callback fires late
- **WHEN** a pin, explorer, or session-load restoration callback from a previous workspace becomes ready after another workspace is active
- **THEN** it does not modify the active workspace or overwrite either workspace's stored state

#### Scenario: Empty state clears stale state
- **WHEN** the destination has an existing saved snapshot with empty buffers, pins, breakpoints, or explorer expansions
- **THEN** the corresponding stale runtime or session state is cleared rather than inherited from the source or an older destination session

#### Scenario: Missing sidecar preserves valid session state
- **WHEN** a destination session exists but a corresponding sidecar does not
- **THEN** valid state restored from that session is not erased merely because the sidecar is absent

#### Scenario: Rapid action requests
- **WHEN** another managed creation, switching, or deletion action is requested before the active action finishes
- **THEN** it is refused with a visible busy explanation rather than interleaving transitions

## REMOVED Requirements

### Requirement: Unsaved-edit transition guard
**Reason**: The transition guards are part of the `git-worktree` plugin's switch protocol.
**Migration**: Carried over unchanged into `openspec/specs/worktree-workspaces/spec.md` in RayIci/git-worktree.nvim.

### Requirement: Live-resource transition guard
**Reason**: The transition guards are part of the `git-worktree` plugin's switch protocol; the debugger check is provided by its nvim-dap integration, which this configuration enables.
**Migration**: Carried over unchanged into `openspec/specs/worktree-workspaces/spec.md` in RayIci/git-worktree.nvim.

### Requirement: Recoverable workspace transition failures
**Reason**: Failure handling and recovery are part of the `git-worktree` plugin's switch protocol.
**Migration**: Carried over unchanged into `openspec/specs/worktree-workspaces/spec.md` in RayIci/git-worktree.nvim.
