---Plugin installation through native vim.pack (see :h vim.pack).
---Lockfile: nvim-pack-lock.json next to init.lua — keep it under version control.
---Update flow: :lua vim.pack.update()  ->  review buffer  ->  :write to apply.
---
---`install()` is the single installer: this file's plugin list and the
---language packs (lua/langs/init.lua) both go through it.
---@class ConfigPack
local M = {}

---One plugin to install.
---@class PackSpec
---@field src string "owner/name" GitHub shorthand or full URL
---@field name? string overrides the name vim.pack derives from src
---@field version? string|vim.VersionRange
---@field build? fun(path: string) run after the plugin is installed or updated

---Build hooks by plugin name, filled by install(); one PackChanged handler
---serves every call.
---@type table<string, fun(path: string)>
local builds = {}

vim.api.nvim_create_autocmd("PackChanged", {
  group = vim.api.nvim_create_augroup("config.pack.build", { clear = true }),
  callback = function(ev)
    local hook = builds[ev.data.spec.name]
    if hook and (ev.data.kind == "install" or ev.data.kind == "update") then
      hook(ev.data.path)
    end
  end,
})

---Install and load plugins with one vim.pack.add() call. Build hooks are
---registered first, so they also run on the first install.
---@param specs (string|PackSpec)[] "owner/name" shorthand or full specs
function M.install(specs)
  local add = {} ---@type vim.pack.Spec[]
  for _, spec in ipairs(specs) do
    spec = type(spec) == "string" and { src = spec } or spec
    local src = spec.src:match("^https?://") and spec.src or ("https://github.com/" .. spec.src)
    if spec.build then
      builds[spec.name or (src:match("([^/]+)$"):gsub("%.git$", ""))] = spec.build
    end
    add[#add + 1] = { src = src, name = spec.name, version = spec.version }
  end
  if #add > 0 then
    vim.pack.add(add, { confirm = false })
  end
end

M.install({
  -- Libraries
  "nvim-lua/plenary.nvim",
  "MunifTanjim/nui.nvim",
  "nvim-tree/nvim-web-devicons",
  "kevinhwang91/promise-async",

  -- LSP / tooling
  "neovim/nvim-lspconfig",
  "mason-org/mason.nvim",
  "WhoIsSethDaniel/mason-tool-installer.nvim",
  { src = "nvim-treesitter/nvim-treesitter", version = "main" },
  "folke/lazydev.nvim",
  "kevinhwang91/nvim-ufo",
  "kosayoda/nvim-lightbulb",
  "nvimdev/lspsaga.nvim",

  -- Completion
  { src = "Saghen/blink.cmp", version = vim.version.range("1") },
  "Saghen/blink.compat",
  "rcarriga/cmp-dap",
  "rafamadriz/friendly-snippets",

  -- Format / lint
  "stevearc/conform.nvim",
  "mfussenegger/nvim-lint",

  -- Debugging & tasks
  "mfussenegger/nvim-dap",
  "rcarriga/nvim-dap-ui",
  "theHamsta/nvim-dap-virtual-text",
  "LiadOz/nvim-dap-repl-highlights",
  "nvim-neotest/nvim-nio",
  "mfussenegger/nvim-dap-python",
  "stevearc/overseer.nvim",
  "nvim-neotest/neotest",

  -- Git & AI
  "lewis6991/gitsigns.nvim",
  "sindrets/diffview.nvim",
  "NeogitOrg/neogit",
  "akinsho/git-conflict.nvim",
  -- octo: pinned to the old-config commit — newer versions are bugged.
  { src = "pwntester/octo.nvim", version = "7566ab21843bf0de721f72891733c0372738d3ee" },
  "zbirenbaum/copilot.lua",
  "folke/sidekick.nvim",
  "RayIci/agentdiff.nvim",

  -- Pickers / navigation
  -- telescope on master: 0.1.x calls the removed vim.treesitter ft_to_lang API
  -- on Neovim 0.12. (The old selection right-shift was a caret-width issue in
  -- our config, not a telescope version problem — see plugins/telescope.lua.)
  "nvim-telescope/telescope.nvim",
  {
    src = "nvim-telescope/telescope-fzf-native.nvim",
    build = function(path)
      vim.system({ "make" }, { cwd = path }):wait()
    end,
  },
  "nvim-telescope/telescope-ui-select.nvim",
  "folke/flash.nvim",
  "RRethy/vim-illuminate",
  "MagicDuck/grug-far.nvim",
  "christoomey/vim-tmux-navigator",

  -- UI
  "folke/snacks.nvim",
  "folke/which-key.nvim",
  "folke/noice.nvim",
  "folke/trouble.nvim",
  "folke/todo-comments.nvim",
  "lukas-reineke/indent-blankline.nvim",
  "nvim-lualine/lualine.nvim",
  "akinsho/bufferline.nvim",
  -- Winbar breadcrumbs (VSCode-style symbol path at cursor)
  "SmiteshP/nvim-navic",
  "utilyre/barbecue.nvim",
  "nvim-neo-tree/neo-tree.nvim",
  "stevearc/oil.nvim",
  "akinsho/toggleterm.nvim",
  "tiagovla/scope.nvim",
  "s1n7ax/nvim-window-picker",
  "MeanderingProgrammer/render-markdown.nvim",
  "rmagatti/auto-session",

  -- Editing
  "kylechui/nvim-surround",
  "windwp/nvim-autopairs",
  "HiPhish/rainbow-delimiters.nvim",
  "NMAC427/guess-indent.nvim",
  "max397574/better-escape.nvim",
  { src = "jake-stewart/multicursor.nvim", version = "1.0" },

  -- Themes
  { src = "catppuccin/nvim", name = "catppuccin" },
  "folke/tokyonight.nvim",
  "rebelot/kanagawa.nvim",
  "ellisonleao/gruvbox.nvim",
  { src = "rose-pine/neovim", name = "rose-pine" },
  "EdenEast/nightfox.nvim",
  "navarasu/onedark.nvim",
  "neanias/everforest-nvim",
  "shaunsingh/nord.nvim",
  "projekt0n/github-nvim-theme",
  "Mofiqul/dracula.nvim",
  "nyoom-engineering/oxocarbon.nvim",
  "sainnhe/sonokai",
  "bluz71/vim-nightfly-colors",
  "Shatur/neovim-ayu",
  "marko-cerovac/material.nvim",
  "scottmckendry/cyberdream.nvim",
  "zaldih/themery.nvim",
})

return M
