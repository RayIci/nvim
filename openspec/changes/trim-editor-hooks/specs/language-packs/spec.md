# Spec Delta

## MODIFIED Requirements

### Requirement: Enriched python pack
The python pack SHALL keep basedpyright and ruff as LSP servers, with ruff's diagnostics coming only from its language server, and additionally provide: mypy linting; ruff formatting extended with `ruff_organize_imports` and `ruff_fix`; venv-selector.nvim with a `<leader>-pp` picker whose selected environment activates in new terminals (falling back to the `./.venv`/`./venv` convention when nothing is selected); pymple.nvim for import management; vim-python-pep8-indent; and a neotest-python adapter using pytest.

#### Scenario: Venv selection drives terminals
- **WHEN** the user selects a virtualenv via `<leader>-pp` and opens a new toggleterm terminal
- **THEN** the terminal sources that virtualenv's activate script

#### Scenario: Dual linting
- **WHEN** a Python file with a type error and a lint violation is saved
- **THEN** both mypy and ruff diagnostics appear, and each ruff finding appears once, not twice
