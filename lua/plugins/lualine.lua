---lualine.nvim: statusline with mode, branch, diff, diagnostics, LSP clients,
---and a macro-recording indicator (noice hides the native "recording @x" message).
---@class PluginLualine
local M = {}

---@return string
local function macro_recording()
  local reg = vim.fn.reg_recording()
  if reg == "" then
    return ""
  end
  return "● REC @" .. reg
end

function M.setup()
  -- The statusline doesn't redraw on its own when recording starts/stops.
  vim.api.nvim_create_autocmd({ "RecordingEnter", "RecordingLeave" }, {
    group = vim.api.nvim_create_augroup("config.lualine.recording", { clear = true }),
    callback = function()
      require("lualine").refresh()
    end,
  })

  require("lualine").setup({
    options = {
      theme = "auto",
      globalstatus = true,
      component_separators = { left = "", right = "" },
      section_separators = { left = "", right = "" },
    },
    sections = {
      lualine_a = { "mode" },
      lualine_b = { "branch", "diff", "diagnostics" },
      lualine_c = { { "filename", path = 1 } },
      lualine_x = {
        { macro_recording, color = { fg = "#ff5555", gui = "bold" } },
        {
          ---@return string
          function()
            local clients = vim.lsp.get_clients({ bufnr = 0 })
            if #clients == 0 then
              return ""
            end
            return " " .. table.concat(vim.tbl_map(function(c)
              return c.name
            end, clients), ",")
          end,
        },
        "filetype",
      },
      lualine_y = { "progress" },
      lualine_z = { "location" },
    },
    extensions = { "neo-tree", "nvim-dap-ui", "quickfix", "overseer" },
  })
end

return M
