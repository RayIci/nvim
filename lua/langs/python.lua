---Python language pack: basedpyright (types) + ruff (lint/format) + mypy
---(save-time linter) + debugpy (DAP) + venv-selector + pytest via neotest.

---Active virtualenv name for the statusline, or "" when none is selected or
---venv-selector has not loaded yet (guarded so it is safe at every redraw).
---@return string
local function python_venv()
  local ok, vs = pcall(require, "venv-selector")
  if not ok then
    return ""
  end
  local path = vs.venv()
  if not path or path == "" then
    return ""
  end
  return vim.fn.fnamemodify(path, ":t")
end

---@type LangPack
return {
  treesitter = { "python" },
  lsp = {
    basedpyright = {
      settings = {
        basedpyright = {
          analysis = { typeCheckingMode = "standard" },
        },
      },
    },
    -- ruff's LSP handles lint fixes and organize-imports code actions;
    -- diagnostics also flow through nvim-lint below for save-time runs.
    ruff = {},
  },
  formatters = { python = { "ruff_format", "ruff_organize_imports", "ruff_fix" } },
  linters = { python = { "ruff", "mypy" } },
  ---@param dap table the nvim-dap module
  dap = function(dap)
    -- dap-python registers the debugpy adapter and default configurations;
    -- point it at mason's debugpy virtualenv.
    local debugpy = vim.fn.expand("$MASON/packages/debugpy/venv/bin/python")
    require("dap-python").setup(debugpy)
    local _ = dap -- adapter registration handled by dap-python
  end,
  mason = { "basedpyright", "ruff", "mypy", "debugpy" },
  packs = {
    { src = "linux-cultist/venv-selector.nvim" },
    { src = "Vimjas/vim-python-pep8-indent" },
    {
      src = "alexpasmantier/pymple.nvim",
      build = function(path)
        -- :PympleBuild only exists after pymple.setup() (runs in this pack's
        -- setup during startup), so defer past startup.
        local _ = path
        vim.defer_fn(function()
          pcall(vim.cmd, "PympleBuild")
        end, 2000)
      end,
    },
    { src = "nvim-neotest/neotest-python" },
    -- Live pandas DataFrame preview in a browser UI while debugging (uses DAP
    -- eval); depends on nvim-dap (already global) + debugpy (installed above).
    { src = "RayIci/dataframe-preview.nvim" },
  },
  test = function()
    return require("neotest-python")({
      dap = { justMyCode = false },
      runner = "pytest",
    })
  end,
  statusline = {
    {
      render = python_venv,
      cond = function()
        return vim.bo.filetype == "python"
      end,
      icon = "🐍",
    },
  },
  setup = function()
    require("which-key").add({
      { "<leader>-", group = "Language" },
      { "<leader>-p", group = "Python" },
    })
    vim.keymap.set("n", "<leader>-pp", "<cmd>VenvSelect<cr>", { desc = "Select Python Virtualenv" })

    -- venv-selector is set up eagerly (not deferred to the first Python
    -- FileType). Its cached-venv restore hangs off the Python buffer's own
    -- FileType/BufEnter autocmds; deferring setup to that same FileType arms
    -- those autocmds *after* the buffer's events have already fired, so the
    -- cached venv never restores until an unrelated later buffer switch. Setup
    -- is cheap (registering autocmds); the picker itself stays lazy.
    require("venv-selector").setup({
      options = {
        picker = "telescope",
        -- Refresh the statusline whenever a venv (de)activates — manual
        -- VenvSelect or an automatic cache restore — so the 🐍 indicator
        -- reflects the change immediately instead of only on the next redraw.
        on_venv_activate_callback = function()
          pcall(function()
            require("lualine").refresh()
          end)
        end,
        on_telescope_result_callback = function(data)
          -- Picker results can carry a trailing newline; strip it.
          if data then
            data = data:gsub("[\r\n]+$", "")
          end
          return data
        end,
      },
    })

    -- pymple is heavier and only relevant once a Python buffer exists; keep it
    -- deferred to the first one (vim.pack has no lazy loading, so the plugin is
    -- sourced, but its setup is not).
    local group = vim.api.nvim_create_augroup("langs.python.setup", { clear = true })
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = "python",
      once = true,
      callback = function()
        require("pymple").setup()
        require("dataframe-preview").setup()
      end,
    })

    -- Activate a virtualenv in every new terminal: prefer the venv-selector
    -- selection, fall back to the ./.venv or ./venv convention. Skipped when
    -- the shell already runs inside a venv.
    require("plugins.toggleterm").register_on_create(function(term)
      if vim.env.VIRTUAL_ENV then
        return
      end
      local ok, vs = pcall(require, "venv-selector")
      local selected = ok and vs.venv() or nil
      if selected then
        local activate = vim.fs.joinpath(selected, "bin", "activate")
        if vim.fn.filereadable(activate) == 1 then
          vim.api.nvim_chan_send(term.job_id, "source " .. activate .. "\n")
          return
        end
      end
      for _, dir in ipairs({ ".venv", "venv" }) do
        local activate = vim.fs.joinpath(vim.fn.getcwd(), dir, "bin", "activate")
        if vim.fn.filereadable(activate) == 1 then
          vim.api.nvim_chan_send(term.job_id, "source " .. activate .. "\n")
          return
        end
      end
    end)
  end,
}
