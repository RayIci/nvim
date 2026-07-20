---Python language pack: basedpyright (types) + ruff (lint/format) + mypy
---(save-time linter) + debugpy (DAP) + venv-selector + pytest via neotest.
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
  },
  test = function()
    return require("neotest-python")({
      dap = { justMyCode = false },
      runner = "pytest",
    })
  end,
  setup = function()
    require("which-key").add({
      { "<leader>-", group = "Language" },
      { "<leader>-p", group = "Python" },
    })
    vim.keymap.set("n", "<leader>-pp", "<cmd>VenvSelect<cr>", { desc = "Select Python Virtualenv" })

    -- pymple + venv-selector are ~60ms of startup and only relevant once a
    -- Python buffer exists — defer their setup to the first one (vim.pack has
    -- no lazy loading, so the plugins are sourced, but their setup is not).
    local group = vim.api.nvim_create_augroup("langs.python.setup", { clear = true })
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = "python",
      once = true,
      callback = function()
        require("pymple").setup()
        require("venv-selector").setup({
          options = {
            picker = "telescope",
            on_telescope_result_callback = function(data)
              -- Picker results can carry a trailing newline; strip it.
              if data then
                data = data:gsub("[\r\n]+$", "")
              end
              return data
            end,
          },
        })
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
