---Statusline breadcrumbs: the symbol path around the cursor (Class › Method)
---from nvim-navic, which reads the language server's document symbols. It is
---shown by lualine (plugins/lualine.lua) for code buffers only, updates on
---CursorHold (lazy), and <leader>ub toggles it, persisted through config.prefs.
---@class PluginBreadcrumbs
local M = {}

---@type (string|PackSpec)[]
M.spec = {
  "SmiteshP/nvim-navic",
}

M.separator = " › "

---Whether breadcrumbs are on (persisted).
---@return boolean
function M.enabled()
  return require("config.prefs").get("breadcrumbs", true)
end

---The breadcrumb for the current buffer, or "" (off, not a file buffer, no
---document-symbol server attached, or cursor outside every symbol).
---@return string
function M.component()
  if not M.enabled() or vim.bo.buftype ~= "" then
    return ""
  end
  local ok, navic = pcall(require, "nvim-navic")
  if not ok or not navic.is_available() then
    return ""
  end
  return navic.get_location()
end

function M.setup()
  require("nvim-navic").setup({
    lsp = { auto_attach = true }, -- every client with documentSymbolProvider
    lazy_update_context = true, -- CursorHold, not every CursorMoved
    highlight = false, -- plain text in the statusline
    separator = M.separator,
    depth_limit = 4,
  })

  vim.keymap.set("n", "<leader>ub", function()
    local on = require("config.prefs").toggle("breadcrumbs", true)
    pcall(function()
      require("lualine").refresh()
    end)
    vim.notify("Breadcrumbs: " .. (on and "on" or "off"))
  end, { desc = "Toggle breadcrumbs (persisted)" })
end

return M
