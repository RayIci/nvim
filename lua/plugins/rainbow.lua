---rainbow-delimiters.nvim: colored nested brackets with a persisted toggle.
---The plugin's enable/disable API is per-buffer, so the global toggle walks
---loaded buffers and an autocmd keeps new buffers in line with the pref.
---@class PluginRainbow
local M = {}

---@param enabled boolean
local function apply_all(enabled)
  local rd = require("rainbow-delimiters")
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      if enabled then
        rd.enable(bufnr)
      else
        rd.disable(bufnr)
      end
    end
  end
end

function M.setup()
  local prefs = require("config.prefs")

  -- Keep newly opened buffers consistent with the persisted preference.
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = vim.api.nvim_create_augroup("config.rainbow", { clear = true }),
    callback = function(ev)
      if not prefs.get("rainbow_brackets", true) then
        require("rainbow-delimiters").disable(ev.buf)
      end
    end,
  })

  vim.keymap.set("n", "<leader>ur", function()
    local enabled = prefs.toggle("rainbow_brackets", true)
    apply_all(enabled)
    vim.notify("Rainbow brackets: " .. (enabled and "on" or "off"))
  end, { desc = "Toggle rainbow brackets" })
end

return M
