---Complete partial LSP diagnostics before they are sent back to a server.
---vim.lsp.diagnostic.from() returns a diagnostic's `user_data.lsp` verbatim,
---assuming it is a full lsp.Diagnostic. nvim-lint's generic pattern parser (and
---linters like sqlfluff) store only `{ code = ... }` there, so code-action
---requests carrying those diagnostics (nvim-lightbulb sends every source's
---diagnostics on the cursor line to every server) lack the required `range` and
---`message`; strict servers such as ruff then reject the whole request
---("Ruff failed to handle a request", log: "missing field `range`").
---Fills the missing fields from the vim.Diagnostic, keeping whatever the
---producer set.
---@class PluginLspDiagnosticFix
local M = {}

function M.setup()
  local lsp_diagnostic = vim.lsp.diagnostic
  local orig_from = lsp_diagnostic.from
  ---@diagnostic disable-next-line: duplicate-set-field
  lsp_diagnostic.from = function(diagnostics)
    local converted = orig_from(diagnostics)
    for i, diagnostic in ipairs(diagnostics) do
      local lsp = converted[i]
      if lsp and (lsp.range == nil or lsp.message == nil) then
        -- Rebuild from the vim.Diagnostic alone (no user_data.lsp), then
        -- overlay the producer's fields on top of it.
        local full = orig_from({ vim.tbl_extend("force", diagnostic, { user_data = {} }) })[1]
        converted[i] = vim.tbl_extend("force", full, lsp)
      end
    end
    return converted
  end
end

return M
