---Python language pack: basedpyright (types) + ruff (lint/format) + debugpy (DAP).
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
  formatters = { python = { "ruff_format" } },
  linters = { python = { "ruff" } },
  ---@param dap table the nvim-dap module
  dap = function(dap)
    -- dap-python registers the debugpy adapter and default configurations;
    -- point it at mason's debugpy virtualenv.
    local debugpy = vim.fn.expand("$MASON/packages/debugpy/venv/bin/python")
    require("dap-python").setup(debugpy)
    local _ = dap -- adapter registration handled by dap-python
  end,
  mason = { "basedpyright", "ruff", "debugpy" },
  setup = function()
    -- Activate the project's virtualenv in every new terminal (old-config
    -- pattern, convention-based: ./.venv or ./venv). Skipped when the shell
    -- already runs inside a venv.
    require("plugins.toggleterm").register_on_create(function(term)
      if vim.env.VIRTUAL_ENV then
        return
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
