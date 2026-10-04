# Spec Delta

## ADDED Requirements

### Requirement: Jupyter notebook language pack
The configuration SHALL provide a jupyter pack that syncs percent-format `*.ju.*` files with a JupyterLab notebook through neopyter, in direct mode with Neovim listening on `127.0.0.1:9001`. Each `*.ju.py` file SHALL map to the `.ipynb` of the same base name, created automatically if missing. Buffers attached to neopyter SHALL get buffer-local keymaps under a `<leader>-j` "Jupyter" which-key group:

- run cell (`<leader>-jr`)
- run cell and select next (`<leader>-jn`)
- run all above (`<leader>-ja`)
- run all (`<leader>-jA`)
- restart kernel (`<leader>-jk`)
- restart kernel and run all (`<leader>-jK`)
- connect (`<leader>-jc`)
- status (`<leader>-js`)
- sync buffer to notebook (`<leader>-jy`)

In notebook buffers only (`*.ju.*` files, and an `.ipynb` left open as raw JSON), whether or not neopyter is connected, `<leader>-jt` SHALL open a floating cheat sheet of JupyterLab DataFrame tools (Buckaroo, D-Tale), `<leader>-jh` SHALL open a floating cheat sheet of every supported cell syntax (code, titled code, markdown in string and comment form, raw, line and cell magics) with the run keymaps, and `<leader>-jS` SHALL show a notification with one-line uv and pip commands to set up a project for notebooks and to start JupyterLab. Python buffers SHALL offer kernel-backed completion candidates from neopyter alongside the default sources. `*.ju.*` buffers SHALL be formatted (on save and manually) with code formatting and import sorting only, never with lint autofixes, so that side-effect imports such as `import buckaroo` are never removed. Files that don't match `*.ju.*` SHALL behave exactly as they do under the python pack.

#### Scenario: Live sync to JupyterLab
- **WHEN** JupyterLab is running with the neopyter extension in direct mode on `127.0.0.1:9001` and the user opens `smoke.ju.py`
- **THEN** neopyter connects, `smoke.ipynb` is opened (created if absent) in JupyterLab, and edits to cells in Neovim appear in the notebook

#### Scenario: Notebook shows the buffer's cells after opening
- **WHEN** neopyter opens a notebook in JupyterLab whose file on disk differs from the buffer (for example, a freshly created empty `.ipynb`)
- **THEN** within a few seconds, without any edit, the notebook shows the buffer's cells instead of the on-disk content

#### Scenario: No blank edge lines in synced cells
- **WHEN** cells in a `*.ju.py` are separated by blank lines before the next `# %%`
- **THEN** the notebook's cells contain the cell text without leading or trailing blank lines, and indentation inside the cell is preserved

#### Scenario: Run cell from Neovim
- **WHEN** the cursor is inside a `# %%` cell of an attached buffer and the user presses `<leader>-jr`
- **THEN** that cell executes in the JupyterLab kernel and its output appears in the browser

#### Scenario: Restart kernel
- **WHEN** the user presses `<leader>-jk` in an attached buffer
- **THEN** the notebook's kernel restarts and previously defined names are no longer available

#### Scenario: Project setup commands
- **WHEN** the user presses `<leader>-jS` in a `*.ju.py` buffer
- **THEN** a notification shows, for both uv and pip, a setup command that installs `jupyterlab neopyter ipykernel jupytext` and a run command that starts JupyterLab

#### Scenario: DataFrame tools sheet
- **WHEN** the user presses `<leader>-jt` in a `*.ju.py` buffer
- **THEN** a read-only floating window shows how to install and use Buckaroo and D-Tale in a notebook, and `q` or `<Esc>` closes it

#### Scenario: Cell syntax sheet
- **WHEN** the user presses `<leader>-jh` in a `*.ju.py` buffer
- **THEN** a read-only floating window titled "Notebook cells" shows each cell syntax with an example, every example syncs to the intended notebook cell type, and `q` or `<Esc>` closes it

#### Scenario: Keymaps scoped to notebooks
- **WHEN** the user opens a plain `.py` file that does not match `*.ju.*`
- **THEN** no `<leader>-j` mappings exist in that buffer, including `<leader>-jS` and `<leader>-jt`

#### Scenario: Kernel completion
- **WHEN** the user types `%ti` in an attached buffer with an active connection
- **THEN** the completion menu offers magic candidates such as `%timeit` from the Neopyter source

#### Scenario: Notebook formatted on save without lint fixes
- **WHEN** a `*.ju.py` buffer with an over-long line, unsorted imports, an unused side-effect `import buckaroo` and a `# %timeit` magic is saved
- **THEN** the long line is reformatted and the imports are sorted, while `import buckaroo` and the `# %timeit` line are kept unchanged

#### Scenario: Plain Python keeps its full formatter chain
- **WHEN** a plain `.py` file with an unused import is saved
- **THEN** the python pack's full formatter chain, including lint autofixes, runs as before

### Requirement: Jupyter notebook pairing
The jupyter pack SHALL treat a `*.ju.py` file as the source of truth for the `.ipynb` of the same base name (`X.ju.py` ↔ `X.ipynb`, including dotted names such as `X.v2.ju.py` ↔ `X.v2.ipynb`). It SHALL import existing notebooks into that format with jupytext, so that neopyter syncs them back cell for cell:
- markdown cells as `"""` blocks;
- line magics as `# %magic`;
- cell magics as `# %%` followed by `# %%<magic>`;
- no header before the first cell.

The pack SHALL NOT let neopyter replace notebook cells that the `.ju.py` doesn't contain without asking the user first. When jupytext is unavailable, opening an `.ipynb` SHALL show its raw JSON and report the error.

#### Scenario: Open an existing notebook
- **WHEN** the user opens `analysis.ipynb` and no `analysis.ju.py` exists
- **THEN** `analysis.ju.py` is created from the notebook's cells and opened in its place, attached to neopyter, and no `.ipynb` buffer remains

#### Scenario: Open a new or empty notebook
- **WHEN** the user opens `scratch.ipynb` that doesn't exist yet or is 0 bytes (for example, just created from the file tree)
- **THEN** `scratch.ipynb` is written as a valid empty Python 3 notebook, and `scratch.ju.py` is created with one empty `# %%` cell, opened and attached to neopyter, with no import error

#### Scenario: Open a notebook that is already paired
- **WHEN** the user opens `analysis.ipynb` and `analysis.ju.py` exists
- **THEN** `analysis.ju.py` is opened without being regenerated

#### Scenario: New .ju.py next to an existing notebook
- **WHEN** the user creates `analysis.ju.py` while `analysis.ipynb` exists
- **THEN** the buffer starts with the notebook's cells, not empty, so the notebook isn't wiped on the first sync

#### Scenario: New .ju.py without a notebook
- **WHEN** the user creates `scratch.ju.py` and no notebook with cells exists for it
- **THEN** the buffer starts with one empty `# %%` cell and is attached to neopyter

#### Scenario: Notebook changed elsewhere
- **WHEN** `analysis.ipynb` was modified after `analysis.ju.py` and contains cell source the `.ju.py` lacks, and the user opens `analysis.ju.py`
- **THEN** the user is asked to either import the notebook (overwriting the `.ju.py`) or keep the `.ju.py` (letting neopyter overwrite the notebook), before neopyter syncs

#### Scenario: Notebook only re-saved by JupyterLab
- **WHEN** `analysis.ipynb` is newer than `analysis.ju.py` but its cell sources match, for example because only outputs changed
- **THEN** `analysis.ju.py` opens without a prompt

#### Scenario: Magics round-trip
- **WHEN** a notebook with a `%timeit` cell and a `%%bash` cell is imported and synced to JupyterLab
- **THEN** the notebook's cells contain `%timeit ...` and `%%bash` + body exactly as they did before the import
