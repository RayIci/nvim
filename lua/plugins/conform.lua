---conform.nvim: formatting with per-language formatters from language packs.
---@class PluginConform
local M = {}

function M.setup()
  vim.keymap.set({ "n", "v" }, "<leader>cf", function()
    require("conform").format({ async = true, lsp_format = "fallback" })
  end, { desc = "Format buffer/selection" })

  vim.keymap.set("n", "<leader>uf", function()
    local prefs = require("config.prefs")
    local enabled = prefs.toggle("format_on_save", true)
    vim.notify("Format on save: " .. (enabled and "on" or "off"))
  end, { desc = "Toggle format on save" })
end

---@param formatters_by_ft table<string, string[]> from the merged language packs
function M.apply(formatters_by_ft)
  require("conform").setup({
    formatters_by_ft = formatters_by_ft,
    format_on_save = function(bufnr)
      if not require("config.prefs").get("format_on_save", true) then
        return nil
      end
      local _ = bufnr
      return { timeout_ms = 1000, lsp_format = "fallback" }
    end,
  })
end

return M
