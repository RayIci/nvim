---conform.nvim: formatting with per-language formatters from language packs.
---@class PluginConform
local M = {}

local function format()
  require("conform").format({ async = true, lsp_format = "fallback" })
end

local function save_without_format()
  vim.b.conform_skip_once = true
  vim.cmd.write()
end

function M.setup()
  vim.api.nvim_create_user_command("Format", format, { desc = "Format buffer" })
  vim.api.nvim_create_user_command(
    "SaveWithoutFormatting",
    save_without_format,
    { desc = "Save without formatting" }
  )

  vim.keymap.set({ "n", "v" }, "<leader>cf", format, { desc = "Format buffer/selection" })

  vim.keymap.set("n", "<leader>uf", function()
    local prefs = require("config.prefs")
    local enabled = prefs.toggle("format_on_save", true)
    vim.notify("Format on save: " .. (enabled and "on" or "off"))
  end, { desc = "Toggle format on save" })

  -- One-shot save that skips format-on-save (shadows normal-mode increment;
  -- visual-mode <C-a> increment still works).
  vim.keymap.set("n", "<C-a>", save_without_format, { desc = "Save without formatting" })
  vim.keymap.set("i", "<C-a>", function()
    vim.cmd.stopinsert()
    save_without_format()
  end, { desc = "Save without formatting" })
end

---@param formatters_by_ft table<string, string[]> from the merged language packs
function M.apply(formatters_by_ft)
  require("conform").setup({
    formatters_by_ft = formatters_by_ft,
    format_on_save = function(bufnr)
      -- One-shot bypass set by the <C-a> save
      if vim.b[bufnr].conform_skip_once then
        vim.b[bufnr].conform_skip_once = nil
        return nil
      end
      if not require("config.prefs").get("format_on_save", true) then
        return nil
      end
      return { timeout_ms = 1000, lsp_format = "fallback" }
    end,
  })
end

return M
