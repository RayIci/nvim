---lazydev.nvim: Neovim runtime + plugin typings for lua_ls, so the config
---itself is fully type-checked (LuaCATS annotations resolve against real types).
---@class PluginLazydev
local M = {}

function M.setup()
  require("lazydev").setup({
    library = {
      -- Load luvit types when vim.uv is referenced
      { path = "${3rd}/luv/library", words = { "vim%.uv" } },
    },
  })
end

return M
