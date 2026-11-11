---nvim-lint: linting with per-language linters from language packs.
---Runs when a buffer is opened (filetype set) and saved, and on entering it or
---leaving insert mode when it changed since its last lint. Never while typing:
---<leader>ud (live diagnostics) only affects how diagnostics are displayed.
---@class PluginLint
local M = {}

---@type (string|PackSpec)[]
M.spec = {
  "mfussenegger/nvim-lint",
}

function M.setup() end

---@param linters_by_ft table<string, string[]> from the merged language packs
function M.apply(linters_by_ft)
  local lint = require("lint")
  lint.linters_by_ft = linters_by_ft

  local group = vim.api.nvim_create_augroup("config.lint", { clear = true })

  ---Lint `buf`; it is clean until its text changes again.
  ---@param buf integer
  local function try_lint(buf)
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modifiable then
      vim.b[buf].lint_dirty = false
      vim.api.nvim_buf_call(buf, function()
        lint.try_lint(nil, { ignore_errors = true })
      end)
    end
  end

  -- Always: when the filetype is set (open, and again on reload — FileType,
  -- not BufReadPost, because this group is created before filetypedetect)
  -- and on save.
  vim.api.nvim_create_autocmd({ "FileType", "BufWritePost" }, {
    group = group,
    callback = function(ev)
      try_lint(ev.buf)
    end,
  })

  -- Text changes only mark the buffer dirty (no linting while typing).
  -- (changedtick can't be the test: Neovim bumps it while opening a file.)
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group,
    callback = function(ev)
      vim.b[ev.buf].lint_dirty = true
    end,
  })

  -- Entering the buffer or leaving insert mode: only when it changed since
  -- its last lint, so an edit-free <Esc> or a buffer switch never restarts a
  -- slow linter (mypy, checkstyle, sqlfluff).
  vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave" }, {
    group = group,
    callback = function(ev)
      if vim.b[ev.buf].lint_dirty then
        try_lint(ev.buf)
      end
    end,
  })
end

return M
