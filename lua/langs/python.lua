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
}
