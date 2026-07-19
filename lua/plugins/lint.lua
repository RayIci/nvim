---nvim-lint: linting with per-language linters from language packs.
---Baseline runs: buffer open, save, and leaving insert mode. When the
---diagnostics-live pref is on (<leader>ud), edits also lint debounced while
---typing — matching vim.diagnostic's update_in_insert display toggle.
---@class PluginLint
local M = {}

function M.setup() end

---@param linters_by_ft table<string, string[]> from the merged language packs
function M.apply(linters_by_ft)
  local lint = require("lint")
  local prefs = require("config.prefs")
  lint.linters_by_ft = linters_by_ft

  local group = vim.api.nvim_create_augroup("config.lint", { clear = true })

  ---@param buf integer
  local function try_lint(buf)
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modifiable then
      vim.api.nvim_buf_call(buf, function()
        lint.try_lint(nil, { ignore_errors = true })
      end)
    end
  end

  vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave" }, {
    group = group,
    callback = function(ev)
      try_lint(ev.buf)
    end,
  })

  -- Live-typing lint runs, debounced; active only while the pref is on.
  local timer = assert(vim.uv.new_timer())
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group,
    callback = function(ev)
      if not prefs.get("diagnostics_live", false) then
        return
      end
      timer:stop()
      timer:start(400, 0, vim.schedule_wrap(function()
        try_lint(ev.buf)
      end))
    end,
  })
end

return M
