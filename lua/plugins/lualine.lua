---lualine.nvim: statusline with mode, branch, diff, diagnostics, LSP clients.
---@class PluginLualine
local M = {}

function M.setup()
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
