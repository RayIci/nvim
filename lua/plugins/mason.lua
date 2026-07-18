---mason.nvim + mason-tool-installer: external tool installation.
---@class PluginMason
local M = {}

function M.setup()
  require("mason").setup()
end

---Install every tool declared by language packs (plus global tools).
---@param tools string[] mason package names from the merged language packs
function M.apply(tools)
  local ensure = vim.list_extend({
    -- Global, language-independent tools
    "copilot-language-server",
  }, tools)

  require("mason-tool-installer").setup({
    ensure_installed = ensure,
    run_on_start = true,
  })
end

return M
