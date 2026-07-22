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
  gh("kevinhwang91/promise-async"),

  -- LSP / tooling
  gh("neovim/nvim-lspconfig"),
  gh("mason-org/mason.nvim"),
  gh("WhoIsSethDaniel/mason-tool-installer.nvim"),
  { src = gh("nvim-treesitter/nvim-treesitter"), version = "main" },
  gh("folke/lazydev.nvim"),
  gh("kevinhwang91/nvim-ufo"),
  gh("kosayoda/nvim-lightbulb"),
  gh("nvimdev/lspsaga.nvim"),

  -- Completion
  { src = gh("Saghen/blink.cmp"), version = vim.version.range("1") },
  gh("Saghen/blink.compat"),
  gh("rcarriga/cmp-dap"),
  gh("rafamadriz/friendly-snippets"),

  -- Format / lint
  gh("stevearc/conform.nvim"),
  gh("mfussenegger/nvim-lint"),

  -- Debugging & tasks
  gh("mfussenegger/nvim-dap"),
  gh("rcarriga/nvim-dap-ui"),
  gh("theHamsta/nvim-dap-virtual-text"),
  gh("LiadOz/nvim-dap-repl-highlights"),
  gh("nvim-neotest/nvim-nio"),
  gh("mfussenegger/nvim-dap-python"),
  gh("stevearc/overseer.nvim"),
  gh("nvim-neotest/neotest"),

  -- Git & AI
  gh("lewis6991/gitsigns.nvim"),
  gh("sindrets/diffview.nvim"),
  gh("NeogitOrg/neogit"),
  gh("akinsho/git-conflict.nvim"),
  -- octo: pinned to the old-config commit — newer versions are bugged.
  { src = gh("pwntester/octo.nvim"), version = "7566ab21843bf0de721f72891733c0372738d3ee" },
  gh("zbirenbaum/copilot.lua"),
  gh("CopilotC-Nvim/CopilotChat.nvim"),

  -- Pickers / navigation
  -- telescope on master: 0.1.x calls the removed vim.treesitter ft_to_lang API
  -- on Neovim 0.12. (The old selection right-shift was a caret-width issue in
  -- our config, not a telescope version problem — see plugins/telescope.lua.)
  gh("nvim-telescope/telescope.nvim"),
  gh("nvim-telescope/telescope-fzf-native.nvim"),
  gh("nvim-telescope/telescope-ui-select.nvim"),
  gh("folke/flash.nvim"),
  gh("RRethy/vim-illuminate"),
  gh("MagicDuck/grug-far.nvim"),
  gh("christoomey/vim-tmux-navigator"),

  -- UI
  gh("folke/which-key.nvim"),
  gh("folke/noice.nvim"),
  gh("folke/trouble.nvim"),
  gh("folke/todo-comments.nvim"),
  gh("lukas-reineke/indent-blankline.nvim"),
  gh("nvim-lualine/lualine.nvim"),
  gh("akinsho/bufferline.nvim"),
  -- Winbar breadcrumbs (VSCode-style symbol path at cursor)
  gh("SmiteshP/nvim-navic"),
  gh("utilyre/barbecue.nvim"),
  gh("nvim-neo-tree/neo-tree.nvim"),
  gh("akinsho/toggleterm.nvim"),
  gh("tiagovla/scope.nvim"),
  gh("s1n7ax/nvim-window-picker"),
  gh("MeanderingProgrammer/render-markdown.nvim"),
  gh("rmagatti/auto-session"),

  -- Editing
  gh("kylechui/nvim-surround"),
  gh("windwp/nvim-autopairs"),
  gh("HiPhish/rainbow-delimiters.nvim"),
  gh("NMAC427/guess-indent.nvim"),
  gh("max397574/better-escape.nvim"),
  { src = gh("jake-stewart/multicursor.nvim"), version = "1.0" },

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
  gh("projekt0n/github-nvim-theme"),
  gh("Mofiqul/dracula.nvim"),
  gh("nyoom-engineering/oxocarbon.nvim"),
  gh("sainnhe/sonokai"),
  gh("bluz71/vim-nightfly-colors"),
  gh("Shatur/neovim-ayu"),
  gh("marko-cerovac/material.nvim"),
  gh("scottmckendry/cyberdream.nvim"),
  gh("zaldih/themery.nvim"),
}, { confirm = false })
