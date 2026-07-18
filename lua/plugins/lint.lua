---nvim-lint: linting with per-language linters from language packs.
---@class PluginLint
local M = {}

function M.setup() end

---@param linters_by_ft table<string, string[]> from the merged language packs
function M.apply(linters_by_ft)
  local lint = require("lint")
  lint.linters_by_ft = linters_by_ft

  vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
    group = vim.api.nvim_create_augroup("config.lint", { clear = true }),
    callback = function(ev)
      if vim.bo[ev.buf].modifiable then
        lint.try_lint(nil, { ignore_errors = true })
      end
    end,
  })
end

return M
