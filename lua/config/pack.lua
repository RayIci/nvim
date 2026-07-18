---Plugin list managed by native vim.pack (see :h vim.pack).
---Lockfile: nvim-pack-lock.json next to init.lua — keep it under version control.
---Update flow: :lua vim.pack.update()  ->  review buffer  ->  :write to apply.

---@param repo string owner/name GitHub shorthand
---@return string url
local function gh(repo)
  return "https://github.com/" .. repo
end

-- Build hooks: run after a plugin is installed or updated.
---@type table<string, fun(path: string)>
local build = {
  ["telescope-fzf-native.nvim"] = function(path)
    vim.system({ "make" }, { cwd = path }):wait()
  end,
}

vim.api.nvim_create_autocmd("PackChanged", {
  group = vim.api.nvim_create_augroup("config.pack.build", { clear = true }),
  callback = function(ev)
    local hook = build[ev.data.spec.name]
    if hook and (ev.data.kind == "install" or ev.data.kind == "update") then
      hook(ev.data.path)
    end
  end,
})

vim.pack.add({
  -- Libraries
  gh("nvim-lua/plenary.nvim"),
  gh("MunifTanjim/nui.nvim"),
  gh("nvim-tree/nvim-web-devicons"),

  -- LSP / tooling
  gh("neovim/nvim-lspconfig"),
  gh("mason-org/mason.nvim"),
  gh("WhoIsSethDaniel/mason-tool-installer.nvim"),
  { src = gh("nvim-treesitter/nvim-treesitter"), version = "main" },
  gh("folke/lazydev.nvim"),

  -- Completion
  { src = gh("Saghen/blink.cmp"), version = vim.version.range("1") },
  gh("rafamadriz/friendly-snippets"),

  -- Format / lint
  gh("stevearc/conform.nvim"),
  gh("mfussenegger/nvim-lint"),

  -- Debugging & tasks
  gh("mfussenegger/nvim-dap"),
  gh("rcarriga/nvim-dap-ui"),
  gh("nvim-neotest/nvim-nio"),
  gh("mfussenegger/nvim-dap-python"),
  gh("stevearc/overseer.nvim"),

  -- Git & AI
  gh("lewis6991/gitsigns.nvim"),
  gh("CopilotC-Nvim/CopilotChat.nvim"),

  -- Pickers / navigation
  gh("nvim-telescope/telescope.nvim"),
  gh("nvim-telescope/telescope-fzf-native.nvim"),
  gh("folke/flash.nvim"),
  gh("RRethy/vim-illuminate"),
  gh("MagicDuck/grug-far.nvim"),

  -- UI
  gh("folke/which-key.nvim"),
  gh("folke/noice.nvim"),
  gh("folke/trouble.nvim"),
  gh("folke/todo-comments.nvim"),
  gh("lukas-reineke/indent-blankline.nvim"),
  gh("nvim-lualine/lualine.nvim"),
  gh("akinsho/bufferline.nvim"),
  gh("nvim-neo-tree/neo-tree.nvim"),

  -- Editing
  gh("kylechui/nvim-surround"),
  gh("windwp/nvim-autopairs"),
  gh("HiPhish/rainbow-delimiters.nvim"),
  gh("NMAC427/guess-indent.nvim"),
  gh("mg979/vim-visual-multi"),

  -- Themes
  { src = gh("catppuccin/nvim"), name = "catppuccin" },
  gh("folke/tokyonight.nvim"),
  gh("rebelot/kanagawa.nvim"),
  gh("ellisonleao/gruvbox.nvim"),
  { src = gh("rose-pine/neovim"), name = "rose-pine" },
  gh("EdenEast/nightfox.nvim"),
  gh("navarasu/onedark.nvim"),
  gh("neanias/everforest-nvim"),
  gh("shaunsingh/nord.nvim"),
  gh("zaldih/themery.nvim"),
}, { confirm = false })
