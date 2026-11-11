---vale: theme engine and browser studio (RayIci/vale.nvim). Its bundled vale
---theme comes from the plugin; this configuration's own themes stay in
---themes/ with their loaders in colors/ and lua/lualine/themes/ (the defaults).
---Set up before plugins/theme.lua, which lists vale's colorschemes.
---@class PluginVale
local M = {}

---@type (string|PackSpec)[]
M.spec = {
  "RayIci/vale.nvim",
}

function M.setup()
  require("vale").setup()
  -- :Vale, :Vale new <name>, :Vale edit <name>, :Vale stop
  require("vale.studio").setup()
  vim.keymap.set("n", "<leader>uv", "<cmd>Vale<cr>", { desc = "Vale theme studio" })
end

return M
