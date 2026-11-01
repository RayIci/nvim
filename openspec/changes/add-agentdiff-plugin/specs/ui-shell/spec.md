# Spec Delta

## MODIFIED Requirements

### Requirement: Neo-tree hide lists and advanced yank
The old config's neo-tree hide lists SHALL apply (by name: `.git`, cache dirs, `bin`/`obj`, `node_modules`, `.next`; by pattern: venvs and `*.egg-info`; never shown: `__pycache__` and conform's temporary `.conform.*` files), and `Y` SHALL open the advanced-yank chooser copying the node's filename, stem, absolute path, cwd-relative path, home-relative path, or extension to the clipboard.

#### Scenario: Advanced yank
- **WHEN** the user presses `Y` on a file in neo-tree and picks "Path relative to CWD"
- **THEN** that relative path lands in the system clipboard

#### Scenario: Noise hidden
- **WHEN** a project contains `__pycache__` and `node_modules` directories
- **THEN** `__pycache__` never appears and `node_modules` is hidden by default

#### Scenario: Formatter temp files stay hidden
- **WHEN** the user saves a Markdown file and conform formats it through a temporary `.conform.*` file in the same directory
- **THEN** the temporary file never appears in neo-tree, not even briefly
