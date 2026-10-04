# Tasks

## 1. Format-on-save opt-out

- [x] 1.1 In `lua/plugins/conform.lua` `format_on_save`, return `nil` when `vim.b[bufnr].conform_disable` is truthy (next to the `conform_skip_once` check); verify with `:let b:conform_disable = 1 | w` on a Python file with bad spacing, where the file is saved unformatted, and that unsetting it formats again

## 2. Jupyter language pack

- [x] 2.1 Create `lua/langs/jupyter.lua` returning a `LangPack` with `packs = { { src = "SUSTech-data/neopyter" }, { src = "AbaoFromCUG/websocket.nvim" } }` and `treesitter = { "python" }`; verify that after restart `:lua =vim.pack.get({"neopyter","websocket.nvim"})` lists both as installed
- [x] 2.2 In the pack's `setup()`, call `require("neopyter").setup({ mode = "direct", remote_address = "127.0.0.1:9001", file_pattern = { "*.ju.*" }, on_attach = ... })`; verify that `:checkhealth neopyter` reports no errors on startup
- [x] 2.3 Implement `on_attach(bufnr)` with buffer-local maps `<leader>-jr/jn/ja/jA/jk/jK/jc/js` (descriptions included) and register the `<leader>-j` "Jupyter" which-key group; verify with `:map <leader>-j` in a `*.ju.py` buffer (maps listed) and in a plain `.py` buffer (none)
- [x] 2.4 Add `completion = { providers = { neopyter = { name = "Neopyter", module = "neopyter.blink" } }, per_filetype = { python = { "lsp", "path", "snippets", "buffer", "neopyter" } } }`; verify that LSP, buffer and snippet candidates still appear in a plain `.py` file
- [x] 2.5 Add a `BufReadPre`/`BufNewFile` autocmd on `*.ju.*` that sets `vim.b.conform_disable = true`; verify that saving `smoke.ju.py` leaves the `%timeit` line untouched
- [x] 2.6 Add a `<leader>-jS` mapping (buffer-local on notebook buffers) that notifies the uv and pip setup and run commands; verify that calling the mapping emits all four commands under the "Jupyter project setup" title
- [x] 2.7 Add a `<leader>-jt` floating cheat sheet (buffer-local on notebook buffers) for Buckaroo and D-Tale (Mito dropped: it requires sign-up and sends telemetry by default); verify that it opens as a read-only markdown float that `q` closes, and that its snippets run in the sandbox kernel (`uv add buckaroo dtale`, nbconvert execute)
- [x] 2.8 Scope `<leader>-jS`/`<leader>-jt` to `*.ju.*` buffers and the raw-JSON `.ipynb` fallback; verify that they're absent in a plain `.py` file and present (buffer-local) in `smoke.ju.py`, a redirected `.ipynb` and a raw-JSON `.ipynb`
- [x] 2.9 Add a `<leader>-jh` "Notebook cells" floating cheat sheet (buffer-local on notebook buffers) sharing the tools-sheet window helper; verify that its examples, extracted into a `.ju.py`, parse with neopyter into code/markdown/markdown/raw/line-magic/cell-magic cells and execute without errors

## 3. Lockfile

- [x] 3.1 Confirm `nvim-pack-lock.json` gained `neopyter` and `websocket.nvim` entries, and stage it with the change (`git diff nvim-pack-lock.json`)

## 4. Notebook pairing

- [x] 4.1 Add the jupytext import (`py:percent`, `"""` markdown, header dropped, `language=` cell magics rewritten) and a `BufReadCmd *.ipynb` redirect to the `.ju.py`; verify that opening `~/neopyter-sandbox/existing.ipynb` lands in an attached `existing.ju.py` whose neopyter-parsed cells match the notebook's sources
- [x] 4.2 Seed a new `X.ju.py` from an existing `X.ipynb` on `BufNewFile` and re-read it; verify that `nvim existing.ju.py` (file absent) opens with the notebook's cells and 8 `<leader>-j` maps
- [x] 4.3 Add a `BufReadPre *.ju.py` stale check (newer mtime and a different source fingerprint, then confirm import or keep); verify that a touched-only notebook opens without a prompt, an externally edited cell prompts, "Keep" leaves the `.ju.py` alone and "Import" pulls the edit in
- [x] 4.5 Handle new and 0-byte notebooks (write a minimal Python 3 notebook, seed `.ju.py` with a `# %%` starter) and new `.ju.py` files with no notebook; verify that opening an empty `prova.ipynb`, a missing `nuovo.ipynb` and a new `solo.ju.py` each land in an attached `.ju.py` with no error
- [x] 4.4 Pass a two-extension `filename_mapper` to neopyter so `X.v2.ju.py` ↔ `X.v2.ipynb`
- [x] 4.6 Wrap neopyter's `Notebook:open_or_reveal` to re-sync 1 s and 3 s after opening, and add `<leader>-jy` (manual sync); verify headlessly that the wrapper is installed and `<leader>-jy` runs without a connection
- [x] 4.7 Replace the notebook format opt-out with a per-buffer formatter list (`vim.b.conform_formatters`, honoured by format-on-save and `:Format`), set to `ruff_format` + `ruff_organize_imports` on `*.ju.*`; verify that saving a `.ju.py` reformats it, sorts imports and keeps `import buckaroo` and `# %timeit`, that `:Format` does the same, and that a plain `.py` still runs `ruff_fix`
- [x] 4.8 Set neopyter `parser.trim_whitespace = true` so the blank lines between cells aren't synced as an empty last line; verify that all 35 `showcase.ju.py` cells parse with no leading or trailing whitespace

## 5. End-to-end verification

- [x] 5.1 In `~/neopyter-sandbox`, run `uv run jupyter lab` and check that the Neopyter sidebar shows `direct` / `127.0.0.1:9001`
- [x] 5.2 Run `nvim smoke.ju.py`: `<leader>-js` shows a connected status, `smoke.ipynb` opens in JupyterLab, and typing in a cell updates the browser
- [x] 5.3 Run each cell with `<leader>-jr`/`<leader>-jn`: the counter grows on re-run, and the DataFrame, plot, `%timeit` and `%%bash` outputs render; `<leader>-jk` restart clears `counter`
- [x] 5.4 Type `%ti` and `df.` in the completion cell and confirm `[Neopyter]` candidates appear
- [x] 5.7 Open `showcase.ipynb` (no notebook on disk yet) with JupyterLab running and confirm that its cells appear in the notebook within a few seconds, without typing
- [x] 5.5 Open `existing.ipynb` with JupyterLab running and confirm the notebook keeps its 4 cells, kernel and outputs, and that `%timeit` and `%%bash` run
- [x] 5.6 Run `openspec validate add-jupyter-lang-pack --strict` and confirm it passes
