# editing-experience Delta

## MODIFIED Requirements

### Requirement: Treesitter syntax highlighting
The configuration SHALL use nvim-treesitter (`main` branch) to install parsers declared by language packs and start treesitter highlighting for those filetypes, using the `main`-branch API (`require('nvim-treesitter').install()` + `vim.treesitter.start()`), not the deprecated `configs.setup` API. On top of pack-declared parsers, the configuration SHALL always install a common base set including at least: `vim`, `vimdoc`, `query`, `markdown`, `markdown_inline`, `regex`, `bash`, `diff`, `json`, `yaml`, `toml`, `xml`, `http`, `c`, `lua`, `luadoc`, `make`, `dockerfile`, `editorconfig`, the git parsers (`gitcommit`, `gitignore`, `git_rebase`, `git_config`, `gitattributes`), and `dap_repl`. The merged parser list SHALL be deduplicated.

#### Scenario: Highlighting active
- **WHEN** a file with an installed parser is opened
- **THEN** treesitter highlighting is active for that buffer

#### Scenario: Git file highlighting without a git language pack
- **WHEN** an interactive rebase todo or `.gitignore` file is opened
- **THEN** treesitter highlighting is active via the always-installed git parsers
