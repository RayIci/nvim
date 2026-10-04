---Jupyter language pack: neopyter syncs percent-format `*.ju.*` files with a
---JupyterLab notebook (direct mode: nvim listens, the browser connects). The
---kernel and rich output live in JupyterLab; editing stays in nvim.
---Requires `pip install neopyter` (JupyterLab >= 4) on the Jupyter side, and
---jupytext (on PATH, or run through `uvx`) to import existing notebooks.
---
---Sync is one-way (buffer -> notebook: neopyter replaces the notebook's cells),
---so the `.ju.py` is the source of truth. `X.ipynb` pairs with `X.ju.py`:
---  - opening `X.ipynb` opens `X.ju.py`, importing it with jupytext if missing
---  - a new `X.ju.py` next to an existing `X.ipynb` starts from its cells
---  - opening `X.ju.py` when `X.ipynb` has newer, different cells (edited
---    elsewhere) asks before neopyter overwrites them

local file_pattern = { "*.ju.*" }

---`a/X.ju.py` -> `a/X.ipynb`. Strips exactly two extensions so dotted names
---(`X.v2.ju.py`) round-trip; neopyter's default strips three.
---@param ju string
---@return string
local function ipynb_for(ju)
  return vim.fn.fnamemodify(ju, ":r:r") .. ".ipynb"
end

---@param ipynb string
---@return string
local function ju_for(ipynb)
  return vim.fn.fnamemodify(ipynb, ":r") .. ".ju.py"
end

---Push a notebook's cells from its buffer to JupyterLab (opening the notebook
---there if needed). No-op when not connected.
---@param notebook neopyter.Notebook
local function resync(notebook)
  require("neopyter.async").run(function()
    if vim.api.nvim_buf_is_valid(notebook.bufnr) and notebook:safe_sync() then
      notebook:parse()
      notebook:full_sync()
    end
  end, function() end)
end

---@param bufnr integer
---@return neopyter.Notebook?
local function notebook_for(bufnr)
  local lab = require("neopyter.jupyter").jupyterlab
  for _, notebook in pairs(lab and lab.notebook_map or {}) do
    if notebook.bufnr == bufnr then
      return notebook
    end
  end
end

---neopyter syncs once right after asking JupyterLab to open the notebook, but
---the notebook's file finishes loading afterwards and replaces those cells, so
---it shows the on-disk content until the next edit. Repeat the sync once the
---notebook has had time to load (sync is idempotent, so a spare one is free).
local function patch_open_sync()
  local Notebook = require("neopyter.jupyter.notebook")
  local open_or_reveal = Notebook.open_or_reveal
  assert(open_or_reveal, "neopyter: Notebook.open_or_reveal is gone; drop the jupyter pack's re-sync wrapper")
  ---@diagnostic disable-next-line: duplicate-set-field
  function Notebook:open_or_reveal(...)
    local result = open_or_reveal(self, ...)
    for _, delay in ipairs({ 1000, 3000 }) do
      vim.defer_fn(function()
        resync(self)
      end, delay)
    end
    return result
  end
end

---Buffer-local notebook keymaps, set only on buffers neopyter attaches to.
---@param bufnr integer
local function on_attach(bufnr)
  local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, "<cmd>Neopyter " .. rhs .. "<cr>", { buffer = bufnr, desc = desc })
  end
  map("<leader>-jr", "execute notebook:run-cell", "Run cell")
  map("<leader>-jn", "execute notebook:run-cell-and-select-next", "Run cell and select next")
  map("<leader>-ja", "execute notebook:run-all-above", "Run all above")
  map("<leader>-jA", "execute notebook:run-all-cells", "Run all")
  map("<leader>-jk", "execute kernelmenu:restart", "Restart kernel")
  map("<leader>-jK", "execute notebook:restart-run-all", "Restart kernel and run all")
  map("<leader>-jc", "connect", "Connect to JupyterLab")
  map("<leader>-js", "status", "Neopyter status")
  vim.keymap.set("n", "<leader>-jy", function()
    local notebook = notebook_for(bufnr)
    if notebook then
      resync(notebook)
    end
  end, { buffer = bufnr, desc = "Sync buffer to notebook" })
end

---Rewrite jupytext's cell-magic header (`# %% language="bash"`) into the form
---neopyter understands (`# %%` followed by `# %%bash`).
---@param lines string[]
---@return string[]
local function fix_cell_magics(lines)
  local out = {}
  for _, line in ipairs(lines) do
    local head, lang, tail = line:match('^(# %%%%.-)%s*language="([%w_]+)"(.*)$')
    if head then
      out[#out + 1] = head .. tail
      out[#out + 1] = "# %%" .. lang
    else
      out[#out + 1] = line
    end
  end
  return out
end

---Convert a notebook to neopyter's percent format: markdown cells as `"""`
---blocks, magics commented (`# %timeit`), which neopyter uncomments on sync.
---@param ipynb string
---@return string[]? lines
---@return string? err
local function convert(ipynb)
  local cmd
  if vim.fn.executable("jupytext") == 1 then
    cmd = { "jupytext" }
  elseif vim.fn.executable("uvx") == 1 then
    cmd = { "uvx", "jupytext" }
  else
    return nil, "jupytext not found (pip install jupytext, or install uv)"
  end
  vim.list_extend(cmd, { "--to", "py:percent", "--opt", 'cell_markers="""', "--output", "-", ipynb })
  local res = vim.system(cmd, { text = true }):wait()
  if res.code ~= 0 then
    return nil, vim.trim(res.stderr or "")
  end
  local lines = vim.split(res.stdout, "\n")
  if lines[#lines] == "" then
    table.remove(lines)
  end
  -- Drop everything before the first cell (the jupytext YAML header): neopyter
  -- syncs it as an extra code cell. The kernelspec stays in the .ipynb, since
  -- neopyter replaces only the notebook's cells.
  for i, line in ipairs(lines) do
    if line:match("^# %%%%") then
      lines = vim.list_slice(lines, i)
      break
    end
  end
  return fix_cell_magics(lines)
end

---@param ipynb string
---@return table? notebook decoded JSON, nil if missing, empty or invalid
local function read_notebook(ipynb)
  if vim.fn.getfsize(ipynb) <= 0 then
    return nil
  end
  local ok, nb = pcall(vim.json.decode, table.concat(vim.fn.readfile(ipynb), "\n"))
  if not ok or type(nb) ~= "table" or type(nb.cells) ~= "table" then
    return nil
  end
  return nb
end

---Smallest notebook JupyterLab opens (Python 3 kernel, no cells): used for
---brand-new `.ipynb` files, which editors and file trees create empty.
local empty_notebook = {
  cells = {},
  metadata = {
    kernelspec = { display_name = "Python 3 (ipykernel)", language = "python", name = "python3" },
    language_info = { name = "python" },
  },
  nbformat = 4,
  nbformat_minor = 5,
}

---Starter for a `.ju.py` with nothing to import: one empty code cell.
local starter = { "# %%", "" }

---Write `ipynb`'s cells into `ju`, notifying on failure.
---@param ipynb string
---@param ju string
---@return boolean ok
local function import(ipynb, ju)
  local lines, err = convert(ipynb)
  if not lines then
    vim.notify("Jupyter import failed: " .. err, vim.log.levels.ERROR)
    return false
  end
  vim.fn.writefile(lines, ju)
  vim.notify("Imported " .. vim.fn.fnamemodify(ipynb, ":t") .. " -> " .. vim.fn.fnamemodify(ju, ":t"))
  return true
end

---Cell-source fingerprint, insensitive to how the two formats spell the same
---cells: separator/magic lines, comment markers, quotes and whitespace are
---dropped. Equal fingerprints = nothing in the notebook the `.ju.py` lacks.
---@param text string
---@return string
local function fingerprint(text)
  local kept = {}
  for _, line in ipairs(vim.split(text, "\n")) do
    if not line:match("^#? ?%%%%") then
      kept[#kept + 1] = line
    end
  end
  return (table.concat(kept):gsub("[%s#\"']", ""))
end

---@param ipynb string
---@return string? sources concatenated cell sources, nil if unreadable
local function notebook_sources(ipynb)
  local nb = read_notebook(ipynb)
  if not nb then
    return nil
  end
  local parts = {}
  for _, cell in ipairs(nb.cells) do
    local src = cell.source
    parts[#parts + 1] = type(src) == "table" and table.concat(src) or tostring(src or "")
  end
  return table.concat(parts, "\n")
end

---@param ju string
---@return string
local function ju_sources(ju)
  return table.concat(vim.fn.readfile(ju), "\n")
end

---Before a `.ju.py` loads (so before neopyter syncs it), offer to re-import a
---notebook that was changed after it and holds cells the `.ju.py` lacks.
---@param ju string absolute path
local function check_stale(ju)
  local ipynb = ipynb_for(ju)
  if vim.fn.filereadable(ju) == 0 or vim.fn.filereadable(ipynb) == 0 then
    return
  end
  if vim.fn.getftime(ipynb) <= vim.fn.getftime(ju) then
    return -- notebook older: any differences are unsynced .ju.py edits
  end
  local sources = notebook_sources(ipynb)
  if not sources or fingerprint(sources) == fingerprint(ju_sources(ju)) then
    return -- notebook only re-saved by JupyterLab (outputs, autosave)
  end
  local choice = vim.fn.confirm(
    vim.fn.fnamemodify(ipynb, ":t") .. " has changes not in " .. vim.fn.fnamemodify(ju, ":t") .. ".",
    "&Import notebook (overwrite .ju.py)\n&Keep .ju.py (overwrite notebook)",
    1
  )
  if choice == 1 then
    import(ipynb, ju)
  end
end

---Make sure `ju` exists: import the notebook's cells, or write the starter
---when the notebook is missing, empty (a fresh `touch`) or has no cells.
---@param ipynb string
---@param ju string
---@return boolean ok false only when an import with cells failed
local function ensure_ju(ipynb, ju)
  if vim.fn.filereadable(ju) == 1 then
    return true
  end
  local nb = read_notebook(ipynb)
  if nb and #nb.cells > 0 then
    return import(ipynb, ju)
  end
  if vim.fn.getfsize(ipynb) > 0 and not nb then
    vim.notify(
      "Jupyter: " .. vim.fn.fnamemodify(ipynb, ":t") .. " is not a valid notebook",
      vim.log.levels.ERROR
    )
    return false
  end
  vim.fn.writefile(starter, ju)
  return true
end

---Cheat sheet for the cell syntax neopyter understands, shown by `<leader>-jh`.
local cells_sheet = {
  "# Notebook cells in a .ju.py",
  "",
  "A cell starts at a `# %%` line and runs until the next one.",
  "",
  "## Code cell",
  "",
  "```python",
  "# %%",
  "x = 40 + 2",
  "x  # the last expression is displayed",
  "```",
  "",
  "With a title (shown only in Neovim, not sent to the notebook):",
  "",
  "```python",
  "# %% Load data",
  'df = pd.read_csv("data.csv")',
  "```",
  "",
  "## Markdown cell",
  "",
  "Body in a triple-quoted string (`[md]` is an alias for `[markdown]`):",
  "",
  "```python",
  "# %% [markdown]",
  '"""',
  "## Title",
  "Text, **bold**, lists, tables, math $e^{i\\pi} + 1 = 0$",
  '"""',
  "```",
  "",
  "Or as comment lines; every non-empty line must start with `# `",
  "(a bare `#` turns the cell into raw text):",
  "",
  "```python",
  "# %% [md]",
  "# ## Title",
  "",
  "# Some text",
  "```",
  "",
  "## Raw cell",
  "",
  "Sent as-is, never executed (notes, nbconvert directives):",
  "",
  "```python",
  "# %% [raw]",
  '"""',
  "anything",
  '"""',
  "```",
  "",
  "## Line magic: `# %`",
  "",
  "Write it commented; it runs as a magic in Jupyter and stays valid",
  "Python for LSP and ruff:",
  "",
  "```python",
  "# %%",
  "# %timeit sum(range(1000))",
  "# %matplotlib inline",
  "```",
  "",
  "## Cell magic: `# %%<magic>`",
  "",
  "`# %%`, then the magic as the first line, body in a string",
  "(or `# ` comment lines):",
  "",
  "```python",
  "# %%",
  "# %%bash",
  '"""',
  "echo hello",
  '"""',
  "```",
  "",
  "Others: `%%html`, `%%javascript`, `%%time`, `%%capture out`,",
  "`%%writefile file.py`. Shell lines (`!ls`) are not supported:",
  "use a `%%bash` cell.",
  "",
  "## Run",
  "",
  "| Key           | Action                       |",
  "|---------------|------------------------------|",
  "| `<leader>-jr` | run cell                     |",
  "| `<leader>-jn` | run cell, go to next         |",
  "| `<leader>-ja` | run all above                |",
  "| `<leader>-jA` | run all                      |",
  "| `<leader>-jk` | restart kernel               |",
  "| `<leader>-jK` | restart kernel and run all   |",
  "| `<leader>-jy` | re-sync buffer to notebook   |",
  "",
  "`q` / `<Esc>` to close",
}

---Cheat sheet for JupyterLab DataFrame tools, shown by `<leader>-jt`.
local tools_sheet = {
  "# JupyterLab DataFrame tools",
  "",
  "Install in the project, then restart the kernel (`<leader>-jk`).",
  "Use `yy` to copy a line.",
  "",
  "## Buckaroo — explore a DataFrame",
  "",
  "Every displayed DataFrame becomes a table with per-column stats",
  "(dtype, nulls, uniques, mean) and a mini histogram; sort and search.",
  "",
  "```sh",
  "uv add buckaroo        # or: pip install buckaroo",
  "```",
  "",
  "```python",
  "# %%",
  "import buckaroo  # from now on, displaying a DataFrame uses Buckaroo",
  "",
  "# %%",
  "df",
  "",
  "# %% back to the plain pandas table",
  "from buckaroo import disable",
  "",
  "disable()",
  "```",
  "",
  "## D-Tale — full data explorer (local, no account)",
  "",
  "Spreadsheet-like grid with filters, sorting, column builders, cleaning,",
  "describe/correlations, charts, and Code Export (the pandas code for",
  "everything you did). Served on 127.0.0.1 only; nothing leaves the machine.",
  "",
  "```sh",
  "uv add dtale 'plotly>=6.1.1'      # or: pip install dtale 'plotly>=6.1.1'",
  "# (the plotly pin avoids a kaleido/plotly version warning on import)",
  "```",
  "",
  "```python",
  "# %%",
  "import dtale",
  "",
  "d = dtale.show(df)  # grid in the output; d.open_browser() for a full tab",
  "d",
  "",
  "# %% after editing in the grid",
  "clean = d.data  # the edited DataFrame",
  "```",
  "",
  "Code: D-Tale menu ▸ Code Export. Stop the server with `d.kill()`.",
  "",
  "`q` / `<Esc>` to close",
}

---Show `lines` (markdown) in a centered read-only float; `q`/`<Esc>` close it.
---@param lines string[]
---@param title string
local function open_sheet(lines, title)
  local width = math.min(80, vim.o.columns - 4)
  local height = math.min(#lines, vim.o.lines - 4)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
  })
  vim.wo[win].wrap = true
  for _, lhs in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", lhs, function()
      vim.api.nvim_win_close(win, true)
    end, { buffer = buf, nowait = true, desc = "Close" })
  end
end

---Setup-commands, tools-sheet and cells-sheet keymaps, scoped to notebook buffers (`.ju.*`,
---and an `.ipynb` left open as raw JSON) — independent of neopyter attaching,
---so they work before JupyterLab is even running.
---@param buf integer
local function set_help_maps(buf)
  vim.keymap.set("n", "<leader>-jS", function()
    local pkgs = "jupyterlab neopyter ipykernel jupytext"
    vim.notify(
      table.concat({
        "uv",
        "  setup: uv add " .. pkgs,
        "  run:   uv run jupyter lab",
        "",
        "pip",
        "  setup: pip install " .. pkgs,
        "  run:   jupyter lab",
      }, "\n"),
      vim.log.levels.INFO,
      { title = "Jupyter project setup" }
    )
  end, { buffer = buf, desc = "Jupyter project setup commands" })
  vim.keymap.set("n", "<leader>-jt", function()
    open_sheet(tools_sheet, "Jupyter tools")
  end, { buffer = buf, desc = "Jupyter DataFrame tools" })
  vim.keymap.set("n", "<leader>-jh", function()
    open_sheet(cells_sheet, "Notebook cells")
  end, { buffer = buf, desc = "Jupyter cell syntax" })
end

---Pairing autocmds: route `.ipynb` opens to the `.ju.py`, seed new `.ju.py`
---files from their notebook (or a starter cell), guard against overwriting
---external edits.
local function setup_pairing()
  local group = vim.api.nvim_create_augroup("langs.jupyter.pairing", { clear = true })

  vim.api.nvim_create_autocmd("BufReadCmd", {
    group = group,
    pattern = "*.ipynb",
    callback = function(ev)
      local ipynb = vim.fn.fnamemodify(ev.match, ":p")
      local ju = ju_for(ipynb)
      if vim.fn.getfsize(ipynb) <= 0 then
        -- New or empty file: give JupyterLab a notebook it can open.
        vim.fn.writefile({ vim.json.encode(empty_notebook) }, ipynb)
      end
      if not ensure_ju(ipynb, ju) then
        -- Import failed (no jupytext, invalid JSON): show the raw file.
        vim.api.nvim_buf_set_lines(ev.buf, 0, -1, false, vim.fn.readfile(ipynb))
        vim.bo[ev.buf].filetype = "json"
        vim.bo[ev.buf].modified = false
        set_help_maps(ev.buf)
        return
      end
      vim.schedule(function()
        vim.cmd.edit(vim.fn.fnameescape(ju))
        if vim.api.nvim_buf_is_valid(ev.buf) then
          vim.api.nvim_buf_delete(ev.buf, { force = true })
        end
      end)
    end,
  })

  vim.api.nvim_create_autocmd("BufNewFile", {
    group = group,
    pattern = "*.ju.py",
    callback = function(ev)
      local ju = vim.fn.fnamemodify(ev.match, ":p")
      -- Seed from the notebook (or the starter), then re-read through the
      -- normal path: neopyter only attaches on BufReadPost, which a new
      -- file never fires.
      if ensure_ju(ipynb_for(ju), ju) then
        vim.schedule(function()
          vim.api.nvim_buf_call(ev.buf, function()
            vim.cmd("edit!")
          end)
        end)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    group = group,
    pattern = file_pattern,
    callback = function(ev)
      set_help_maps(ev.buf)
    end,
  })

  vim.api.nvim_create_autocmd("BufReadPre", {
    group = group,
    pattern = "*.ju.py",
    callback = function(ev)
      check_stale(vim.fn.fnamemodify(ev.match, ":p"))
    end,
  })
end

---@type LangPack
return {
  treesitter = { "python" },
  packs = {
    { src = "SUSTech-data/neopyter" },
    { src = "AbaoFromCUG/websocket.nvim" }, -- required by mode = "direct"
  },
  completion = {
    providers = {
      neopyter = { name = "Neopyter", module = "neopyter.blink" },
    },
    -- Explicit list: the pack merger keeps only list items, so blink's
    -- `inherit_defaults` key would be dropped. Mirrors the global defaults
    -- minus lazydev (Lua-only).
    per_filetype = {
      python = { "lsp", "path", "snippets", "buffer", "neopyter" },
    },
  },
  setup = function()
    require("which-key").add({ { "<leader>-j", group = "Jupyter" } })

    -- Registered before neopyter so its BufReadPre stale check runs first.
    setup_pairing()

    -- Set up eagerly (not on the first Python FileType): neopyter attaches via
    -- its own autocmds on file_pattern, which must exist before the first
    -- notebook buffer's events fire (same trap as venv-selector in python.lua).
    -- Its BufReadPost hook resolves the buffer's tree-sitter parser from
    -- 'filetype', so filetypedetect's BufReadPost must be registered first;
    -- nvim only enables it after init.lua, so do it now (idempotent).
    vim.cmd("filetype plugin indent on")
    require("neopyter").setup({
      mode = "direct",
      remote_address = "127.0.0.1:9001",
      file_pattern = file_pattern,
      filename_mapper = ipynb_for,
      -- Drop the blank lines between `# %%` cells from the synced source
      -- (default keeps them, leaving an empty last line in every cell).
      parser = { trim_whitespace = true },
      on_attach = on_attach,
    })
    patch_open_sync()

    -- Notebooks format with ruff_format + ruff_organize_imports only: ruff_fix
    -- deletes "unused" side-effect imports (`import buckaroo`, F401). Magics
    -- must stay commented (`# %timeit`): ruff can't parse bare `%timeit`.
    vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
      group = vim.api.nvim_create_augroup("langs.jupyter.format", { clear = true }),
      pattern = file_pattern,
      callback = function(ev)
        vim.b[ev.buf].conform_formatters = { "ruff_format", "ruff_organize_imports" }
      end,
    })
  end,
}
