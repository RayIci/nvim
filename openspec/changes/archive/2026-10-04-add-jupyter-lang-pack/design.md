# Design

## Context

Plugins are installed by native `vim.pack` and configured with explicit, ordered setup calls; nothing is lazy-loaded. Language-specific plugins live in drop-in packs under `lua/langs/`. The loader merges each pack's `packs`, `treesitter`, `completion` and `setup` and passes them to the subsystems. blink.cmp is configured once, in `plugins/blink.lua` `apply()`, and its `per_filetype` entries *replace* a filetype's list. conform's `format_on_save` gate checks a one-shot buffer flag (`conform_skip_once`) and the global `format_on_save` pref.

## Goals / Non-Goals

**Goals:**
- Add neopyter as a self-contained pack, without changing `pack.lua` or `plugins/init.lua`.
- Keep notebook keymaps buffer-local, so plain Python files are unchanged.
- Let a pack opt a buffer out of format-on-save without changing the user's global preference.

**Non-Goals:**
- Cell textobjects and motions (deferred until nvim-treesitter-textobjects `main` is adopted).
- Proxy mode, remote JupyterLab, or neoconf integration.
- Pulling cell edits made in the JupyterLab UI back into an open buffer while editing; that's only detected the next time the file is opened.
- Suppressing LSP/linter diagnostics on magic lines.
- Installing JupyterLab itself (that's per project, e.g. `uv` in the sandbox).

## Decisions

**A separate `jupyter` pack instead of extending `python.lua`.** The pack framework already dedupes treesitter entries and merges completion. A separate file keeps the notebook dependency (websocket server, JupyterLab extension) easy to remove. *Alternative:* add to `python.lua`. Rejected because that pack is already large, and notebooks are an opt-in workflow.

**Direct mode on `127.0.0.1:9001`.** This is neopyter's default and recommended mode: Neovim runs the server and the browser connects to it. It works for local JupyterLab with no server-side configuration. *Alternative:* proxy mode, which only matters when the browser can't reach Neovim (remote boxes). It would also tie each JupyterLab instance to a single client.

**Setup in the pack's `setup()`, not in a FileType autocmd.** neopyter attaches with its own autocmds on `file_pattern`. If setup were deferred to the first Python FileType, those autocmds would be registered after the first buffer's events had already fired. That's the same trap documented for venv-selector in `python.lua`. neopyter's setup only registers autocmds, so running it eagerly is cheap. neopyter postpones its own setup and the server connection until the first `BufReadPost` of a `*.ju.*` file, so nothing listens on 9001 until a notebook is opened.

**Filetype detection is enabled before neopyter setup.** neopyter's `BufReadPost` hook resolves the buffer's tree-sitter parser from `'filetype'`. Neovim only runs `filetype plugin indent on` after `init.lua`, so neopyter's autocmd would otherwise fire before `filetypedetect`'s. `ft` would then be empty, the parser lookup would fail with "attempt to index a nil value", and the error would stop filetype detection for that buffer. The pack runs `filetype plugin indent on` (idempotent) just before `neopyter.setup()`. *Alternative:* defer setup with `vim.schedule`. Rejected because it misses the argv buffer in `nvim smoke.ju.py`.

**Keymaps in `on_attach` with `buffer = bufnr`, under `<leader>-j`.** This follows the `<leader>-<lang>` group convention (`-p` Python, `-m` Markdown, `-s` solution). Commands use `Neopyter execute notebook:*` / `kernelmenu:*` ids (the README's recommended form) for run commands. `:Neopyter connect` and `:Neopyter status` are used for connection management. *Alternative:* the README's `<C-CR>` / `<S-CR>` / `<F5>`. Rejected: `<F5>` is DAP continue, and modified Enter keys depend on the terminal's keyboard protocol (see `config/keymaps.lua`).

**blink: `per_filetype.python = { "lsp", "path", "snippets", "buffer", "neopyter" }`.** blink replaces per-filetype lists, and the pack merger copies only list items, so blink's `inherit_defaults` key would be dropped. The list therefore copies the global defaults explicitly, minus the Lua-only `lazydev`, which is the same style the sql pack uses. No other pack sets `python`, so nothing is overwritten. The provider is scoped to python and not global. When it has no connection it returns no candidates, so plain `.py` buffers see no difference.

**Per-buffer formatter list: `vim.b.conform_formatters`.** (This replaces an earlier `vim.b.conform_disable` opt-out, which left notebooks unformatted.) Conform's `format_on_save` and the manual `format()` both pass `formatters = vim.b.conform_formatters`. That's nil for ordinary buffers, so they keep their filetype chain. The jupyter pack sets `{ "ruff_format", "ruff_organize_imports" }` on `*.ju.*` from a `BufReadPre`/`BufNewFile` autocmd. `ruff_fix` is excluded because it deletes "unused" side-effect imports (F401, e.g. `import buckaroo`), which silently changes notebook behaviour. Commented magics (`# %timeit`) are untouched by ruff. An uncommented `%timeit` makes ruff fail to parse: conform reports the error and leaves the file unchanged. *Alternatives:* disabling formatting (the first version, which lost formatting), or keeping the full chain (it breaks side-effect imports).

**`.ju.py` is the source of truth, and the pack pairs it with the `.ipynb`.** neopyter can't open an `.ipynb`, and its sync only goes one way: `fullSync` replaces the notebook's cells with the buffer's. The pack fills the gaps with three autocmds:
- `BufReadCmd *.ipynb` imports the notebook if needed and redirects to the `.ju.py`, without reading the JSON, which can be large because of embedded images.
- `BufNewFile *.ju.py` seeds a new file from its notebook, or with a one-cell starter when there's nothing to import, then re-reads it so neopyter's `BufReadPost` attach runs. A brand-new file never fires `BufReadPost`, so without the re-read neopyter wouldn't attach.
- A missing or 0-byte `.ipynb` (which file trees create) is written as a minimal Python 3 notebook before redirecting. jupytext can't read an empty file, and JupyterLab can't open one either.
- `BufReadPre *.ju.py` runs the stale check. It's registered before neopyter's hooks and fires before them, so the prompt always comes before any sync.

*Alternative:* jupytext.nvim, which edits `.ipynb` directly. Rejected because its write path rewrites the notebook from Neovim and fights neopyter's live sync. molten-nvim (in-terminal output) was also rejected, because the work terminal can't render images.

**Import format = what neopyter's parser expects.** The import runs `jupytext --to py:percent --opt cell_markers="""` and then:
- drops the YAML header, because neopyter syncs anything before the first `# %%` as an extra code cell, while the kernelspec survives in the `.ipynb` since only cells are replaced;
- rewrites jupytext's `# %% language="bash"` into `# %%` + `# %%bash`.

jupytext's commented `# %timeit` matches neopyter's line-magic convention and is valid Python, so LSP and ruff stay quiet. jupytext resolves from PATH (the venv), with `uvx jupytext` as a fallback.

**Stale check: mtime, then a source fingerprint.** JupyterLab autosaves the notebook on every sync, so mtime alone would prompt on every open. The prompt only appears when the notebook is newer *and* its cell sources differ from the `.ju.py`. Sources are compared as a fingerprint that drops separator and magic lines, `#`, quotes and whitespace, the characters where the two formats spell the same cells differently. The cost: an external edit that only touches those characters goes undetected, which is acceptable because they're cosmetic.

**`filename_mapper` strips exactly two extensions.** neopyter's default strips three (`:r:r:r`), which maps `X.v2.ju.py` to `X.ipynb`. The pack passes its own `:r:r` mapper, so both directions of the pairing agree.

**Re-sync after neopyter opens a notebook.** neopyter does its only initial `fullSync` right after asking JupyterLab to open the notebook. JupyterLab then finishes loading the file from disk, which replaces those cells, so the notebook shows the stale on-disk content until the next edit. The pack wraps `Notebook:open_or_reveal`, which every path that opens a notebook goes through (attach, cursor move, edit, save), and runs the sync again 1 s and 3 s later. A full sync is idempotent, so the extra one costs nothing. `<leader>-jy` runs the same sync by hand. *Alternative:* writing the cells into the `.ipynb` on disk before opening. Rejected because it needs a second ju → ipynb converter, and it doesn't cover a `.ju.py` edited while JupyterLab was closed.

**`parser.trim_whitespace = true`.** neopyter's default keeps everything up to the next `# %%`, so the blank separator lines (which ruff format enforces) arrive in JupyterLab as an empty last line in every cell. Trimming only touches the ends of each cell's text, so inner indentation and blank lines survive.

## Risks / Trade-offs

- [The port is already in use, or a second Neovim tries to listen on 9001] → The second instance fails to bind. `<leader>-js` (`:Neopyter status`) surfaces this. Run one notebook-editing Neovim at a time, or change the port in both the pack and the JupyterLab sidebar.
- [Uncommented magics typed by hand (`%timeit`) are flagged by basedpyright/ruff and make the format-on-save report a parse error] → Use the commented form (`# %timeit`), which the importer also produces. The file is never modified when ruff can't parse it.
- [Choosing "Keep .ju.py" leaves the notebook stale until neopyter syncs, so the prompt repeats on the next open without JupyterLab] → Expected. Syncing once with JupyterLab running clears it.
- [The open/re-sync wrapper patches a neopyter internal (`Notebook.open_or_reveal`)] → If an update renames it, the pack fails loudly at startup. `<leader>-jy` remains as a manual fallback. Drop the wrapper if upstream fixes the race.
- [The `.ipynb` → `.ju.py` redirect hides the raw JSON] → For a raw view, run `:noautocmd edit X.ipynb`.
- [neopyter `master` tracks Neovim nightly/stable] → The lockfile pins the commit. If an update breaks on 0.12.x, roll back the lock entry.
- [The JupyterLab extension and plugin versions drift apart] → The tasks verify against a fresh `uv` sandbox. Keep `neopyter` pip and plugin updates together.

## Migration Plan

This change is purely additive. To roll back, delete `lua/langs/jupyter.lua`, revert the conform gate line, run `vim.pack.del({ "neopyter", "websocket.nvim" })`, and restore the lockfile.
