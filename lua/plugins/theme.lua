---Theme switcher: themery.nvim over the installed theme set.
---Selection persists automatically in themery's own state file under
---stdpath('state'); on first launch we fall back to catppuccin-mocha.
---@class PluginTheme
local M = {}

function M.setup()
  require("themery").setup({
    themes = {
      -- Catppuccin
      { name = "Catppuccin Mocha", colorscheme = "catppuccin-mocha" },
      { name = "Catppuccin Macchiato", colorscheme = "catppuccin-macchiato" },
      { name = "Catppuccin Frappe", colorscheme = "catppuccin-frappe" },
      { name = "Catppuccin Latte (light)", colorscheme = "catppuccin-latte" },

      -- Tokyonight
      { name = "Tokyonight Storm", colorscheme = "tokyonight-storm" },
      { name = "Tokyonight Night", colorscheme = "tokyonight-night" },
      { name = "Tokyonight Moon", colorscheme = "tokyonight-moon" },
      { name = "Tokyonight Day (light)", colorscheme = "tokyonight-day" },

      -- Kanagawa
      { name = "Kanagawa Wave", colorscheme = "kanagawa-wave" },
      { name = "Kanagawa Dragon", colorscheme = "kanagawa-dragon" },
      { name = "Kanagawa Lotus (light)", colorscheme = "kanagawa-lotus" },

      -- Gruvbox
      { name = "Gruvbox Dark", colorscheme = "gruvbox", before = [[vim.o.background = "dark"]] },
      { name = "Gruvbox Light", colorscheme = "gruvbox", before = [[vim.o.background = "light"]] },

      -- Rose Pine
      { name = "Rose Pine", colorscheme = "rose-pine" },
      { name = "Rose Pine Moon", colorscheme = "rose-pine-moon" },
      { name = "Rose Pine Dawn (light)", colorscheme = "rose-pine-dawn" },

      -- Nightfox family
      { name = "Nightfox", colorscheme = "nightfox" },
      { name = "Duskfox", colorscheme = "duskfox" },
      { name = "Nordfox", colorscheme = "nordfox" },
      { name = "Terafox", colorscheme = "terafox" },
      { name = "Carbonfox", colorscheme = "carbonfox" },
      { name = "Dayfox (light)", colorscheme = "dayfox" },
      { name = "Dawnfox (light)", colorscheme = "dawnfox" },

      -- Onedark
      { name = "Onedark", colorscheme = "onedark", before = [[require("onedark").setup({ style = "dark" })]] },
      { name = "Onedark Darker", colorscheme = "onedark", before = [[require("onedark").setup({ style = "darker" })]] },
      { name = "Onedark Cool", colorscheme = "onedark", before = [[require("onedark").setup({ style = "cool" })]] },
      { name = "Onedark Deep", colorscheme = "onedark", before = [[require("onedark").setup({ style = "deep" })]] },
      { name = "Onedark Warm", colorscheme = "onedark", before = [[require("onedark").setup({ style = "warm" })]] },
      { name = "Onedark Warmer", colorscheme = "onedark", before = [[require("onedark").setup({ style = "warmer" })]] },
      { name = "Onedark Light (light)", colorscheme = "onedark", before = [[require("onedark").setup({ style = "light" })]] },

      -- Everforest
      {
        name = "Everforest Dark Soft",
        colorscheme = "everforest",
        before = [[vim.o.background = "dark"; require("everforest").setup({ background = "soft" })]],
      },
      {
        name = "Everforest Dark Medium",
        colorscheme = "everforest",
        before = [[vim.o.background = "dark"; require("everforest").setup({ background = "medium" })]],
      },
      {
        name = "Everforest Dark Hard",
        colorscheme = "everforest",
        before = [[vim.o.background = "dark"; require("everforest").setup({ background = "hard" })]],
      },
      {
        name = "Everforest Light Soft (light)",
        colorscheme = "everforest",
        before = [[vim.o.background = "light"; require("everforest").setup({ background = "soft" })]],
      },
      {
        name = "Everforest Light Medium (light)",
        colorscheme = "everforest",
        before = [[vim.o.background = "light"; require("everforest").setup({ background = "medium" })]],
      },
      {
        name = "Everforest Light Hard (light)",
        colorscheme = "everforest",
        before = [[vim.o.background = "light"; require("everforest").setup({ background = "hard" })]],
      },

      -- Nord
      { name = "Nord", colorscheme = "nord" },

      -- GitHub Theme
      { name = "GitHub Dark", colorscheme = "github_dark" },
      { name = "GitHub Dark Dimmed", colorscheme = "github_dark_dimmed" },
      { name = "GitHub Dark High Contrast", colorscheme = "github_dark_high_contrast" },
      { name = "GitHub Light (light)", colorscheme = "github_light" },
      { name = "GitHub Light High Contrast (light)", colorscheme = "github_light_high_contrast" },

      -- Dracula
      { name = "Dracula", colorscheme = "dracula" },
      { name = "Dracula Soft", colorscheme = "dracula-soft" },

      -- Oxocarbon
      { name = "Oxocarbon Dark", colorscheme = "oxocarbon", before = [[vim.o.background = "dark"]] },
      { name = "Oxocarbon Light (light)", colorscheme = "oxocarbon", before = [[vim.o.background = "light"]] },

      -- Sonokai
      { name = "Sonokai Default", colorscheme = "sonokai", before = [[vim.g.sonokai_style = "default"]] },
      { name = "Sonokai Atlantis", colorscheme = "sonokai", before = [[vim.g.sonokai_style = "atlantis"]] },
      { name = "Sonokai Andromeda", colorscheme = "sonokai", before = [[vim.g.sonokai_style = "andromeda"]] },
      { name = "Sonokai Shusia", colorscheme = "sonokai", before = [[vim.g.sonokai_style = "shusia"]] },
      { name = "Sonokai Maia", colorscheme = "sonokai", before = [[vim.g.sonokai_style = "maia"]] },
      { name = "Sonokai Espresso", colorscheme = "sonokai", before = [[vim.g.sonokai_style = "espresso"]] },

      -- Nightfly
      { name = "Nightfly", colorscheme = "nightfly" },

      -- Ayu
      { name = "Ayu Dark", colorscheme = "ayu-dark" },
      { name = "Ayu Mirage", colorscheme = "ayu-mirage" },
      { name = "Ayu Light (light)", colorscheme = "ayu-light" },

      -- Material
      { name = "Material Darker", colorscheme = "material", before = [[vim.g.material_style = "darker"]] },
      { name = "Material Oceanic", colorscheme = "material", before = [[vim.g.material_style = "oceanic"]] },
      { name = "Material Palenight", colorscheme = "material", before = [[vim.g.material_style = "palenight"]] },
      { name = "Material Deep Ocean", colorscheme = "material", before = [[vim.g.material_style = "deep ocean"]] },
      { name = "Material Lighter (light)", colorscheme = "material", before = [[vim.g.material_style = "lighter"]] },

      -- Cyberdream
      { name = "Cyberdream", colorscheme = "cyberdream", before = [[require("cyberdream").setup({ variant = "default" })]] },
      { name = "Cyberdream Light (light)", colorscheme = "cyberdream", before = [[require("cyberdream").setup({ variant = "light" })]] },
      {
        name = "Cyberdream Transparent (vibrant, transparent bg)",
        colorscheme = "cyberdream",
        before = [[require("cyberdream").setup({ variant = "default", transparent = true })]],
      },
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
