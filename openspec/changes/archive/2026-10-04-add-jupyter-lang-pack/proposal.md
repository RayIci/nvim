# Proposal

## Why

Notebook work (exploration, plots, DataFrames) currently means leaving Neovim for the JupyterLab editor. In-terminal alternatives such as molten-nvim are ruled out, because the work terminal can't display images or rich output. neopyter connects the two: a `*.ju.py` percent-format file is edited in Neovim with the full Python pack (LSP, completion, keymaps), while JupyterLab holds the kernel and renders the matching `.ipynb` live.

## What Changes

- New `jupyter` language pack (`lua/langs/jupyter.lua`) that installs neopyter and websocket.nvim through the pack framework and sets neopyter up in `direct` mode on `127.0.0.1:9001` for `*.ju.*` files.
- Buffer-local Jupyter keymaps under a new `<leader>-j` which-key group, attached only to neopyter buffers: run cell, run and advance, run all above, run all, restart kernel, restart and run all, connect, status.
- A neopyter blink.cmp completion source for Python buffers that adds kernel-backed candidates (magics, paths, runtime attributes).
- Existing `.ipynb` notebooks are first-class. neopyter's sync only goes one way (it replaces the notebook's cells with the buffer), so the `.ju.py` is the source of truth, and the pack keeps each `X.ipynb` paired with an `X.ju.py`:
  - opening `X.ipynb` opens `X.ju.py`, importing it with jupytext if it doesn't exist yet;
  - a new `X.ju.py` next to an existing `X.ipynb` starts from the notebook's cells instead of empty, which would otherwise wipe the notebook;
  - opening `X.ju.py` when `X.ipynb` was changed elsewhere and has different cells asks before neopyter overwrites them.
- Notebook buffers are formatted (on save and with `:Format`) using only ruff format and import sorting. `ruff_fix` is excluded because it deletes side-effect imports such as `import buckaroo`.
- Conform honours a per-buffer formatter list (`vim.b.conform_formatters`), so a pack can narrow a buffer's formatters without touching other buffers or the global preference.
- The plugin lockfile (`nvim-pack-lock.json`) gains the two new plugins.

Not included: tree-sitter cell textobjects (`aj`/`ij`, `]j`/`[j`). They need nvim-treesitter-textobjects on its `main` branch, which isn't installed yet.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `language-packs`: adds requirements for a Jupyter notebook language pack (neopyter sync, run/kernel keymaps, kernel completion, safe formatter subset for notebook files) and for `.ipynb` ↔ `.ju.py` pairing (import on open, seeding, stale-notebook guard).

## Impact

- **New file:** `lua/langs/jupyter.lua`.
- **Modified:** `lua/plugins/conform.lua` (per-buffer formatter list for format-on-save and `:Format`), `nvim-pack-lock.json`.
- **New plugins:** `SUSTech-data/neopyter` (`master`, which needs Neovim ≥ 0.12) and `AbaoFromCUG/websocket.nvim`.
- **External requirement:** jupytext, on PATH (e.g. in the project venv) or run through `uvx`, to import notebooks.
- **External requirement:** JupyterLab ≥ 4 with the `neopyter` pip extension, running in the browser. Neovim listens on `127.0.0.1:9001`.
- **No conflicts:** neopyter ships no default keymaps. The README suggests `<F5>` (taken by DAP) and `<C-CR>`/`<S-CR>` (terminal-dependent), and neither is used.
