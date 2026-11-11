---nvim-lightbulb: sign-only code-action availability indicator, toggled with
---<leader>ul (persisted through config.prefs, default on). Off means no
---CursorHold code-action requests at all, not just hidden signs.
---@class PluginLightbulb
local M = {}

---@type (string|PackSpec)[]
M.spec = {
  "kosayoda/nvim-lightbulb",
}

---@param enabled boolean
local function configure(enabled)
  -- The plugin adds to its LightBulb group on every setup; start clean.
  vim.api.nvim_create_augroup("LightBulb", { clear = true })
  require("nvim-lightbulb").setup({
    sign = { enabled = true, text = "💡" },
    virtual_text = { enabled = false },
    float = { enabled = false },
    status_text = { enabled = false },
    number = { enabled = false },
    line = { enabled = false },
    autocmd = {
      enabled = enabled,
      updatetime = -1,
      events = { "CursorHold", "CursorHoldI" },
    },
    ignore = {
      ft = {
        "snacks_picker_list",
        "Trouble",
        "trouble",
        "toggleterm",
        "lazy",
        "mason",
        "qf",
        "help",
      },
    },
  })
end

---Whether the lightbulb is on (persisted).
---@return boolean
function M.enabled()
  return require("config.prefs").get("lightbulb", true)
end

function M.setup()
  configure(M.enabled())
  vim.keymap.set("n", "<leader>ul", function()
    local on = require("config.prefs").toggle("lightbulb", true)
    configure(on)
    if not on then
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) then
          require("nvim-lightbulb").clear_lightbulb(buf)
        end
      end
    end
    vim.notify("Code-action lightbulb: " .. (on and "on" or "off"))
  end, { desc = "Toggle code-action lightbulb (persisted)" })
end

return M
