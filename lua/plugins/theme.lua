---Theme switcher: themery.nvim over the installed theme set.
---Selection persists automatically in themery's own state file under
---stdpath('state'); on first launch we fall back to catppuccin-mocha.
---@class PluginTheme
local M = {}

function M.setup()
  require("themery").setup({
    themes = {
      { name = "Catppuccin Mocha", colorscheme = "catppuccin-mocha" },
      { name = "Catppuccin Latte (light)", colorscheme = "catppuccin-latte" },
      { name = "Tokyonight Storm", colorscheme = "tokyonight-storm" },
      { name = "Tokyonight Night", colorscheme = "tokyonight-night" },
      { name = "Kanagawa Wave", colorscheme = "kanagawa-wave" },
      { name = "Kanagawa Dragon", colorscheme = "kanagawa-dragon" },
      { name = "Gruvbox Dark", colorscheme = "gruvbox", before = [[vim.o.background = "dark"]] },
      { name = "Gruvbox Light", colorscheme = "gruvbox", before = [[vim.o.background = "light"]] },
      { name = "Rose Pine", colorscheme = "rose-pine" },
      { name = "Rose Pine Dawn (light)", colorscheme = "rose-pine-dawn" },
      { name = "Nightfox", colorscheme = "nightfox" },
      { name = "Carbonfox", colorscheme = "carbonfox" },
      { name = "Onedark", colorscheme = "onedark" },
      { name = "Everforest", colorscheme = "everforest" },
      { name = "Nord", colorscheme = "nord" },
    },
    livePreview = true,
  })

  -- Themery applies the persisted theme during setup; default otherwise.
  if vim.g.colors_name == nil or vim.g.colors_name == "default" then
    pcall(vim.cmd.colorscheme, "catppuccin-mocha")
  end

  vim.keymap.set("n", "<leader>ut", "<cmd>Themery<cr>", { desc = "Theme switcher" })
end

return M
