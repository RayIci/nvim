---Explicit, ordered plugin setup. Each module configures one plugin (or one
---tight cluster) and owns that plugin's keymaps. Subsystems that consume
---language-pack data expose an apply() called later by require("langs").setup().

-- Core editing/IDE subsystems
require("plugins.mason").setup()
require("plugins.treesitter").setup()
require("plugins.lsp").setup()
require("plugins.blink").setup()
require("plugins.lsp-markdown-fix").setup()
require("plugins.render-markdown").setup()
require("plugins.conform").setup()
require("plugins.lint").setup()
require("plugins.dap").setup()
require("plugins.overseer").setup()
require("plugins.neotest").setup()
require("plugins.toggleterm").setup()

-- AI
require("plugins.copilot").setup()
require("plugins.copilot-chat").setup()

-- Git
require("plugins.gitsigns").setup()
require("plugins.lazygit").setup()
require("plugins.diffview").setup()
require("plugins.neogit").setup()
require("plugins.octo").setup()
require("plugins.git-conflict").setup()

-- Pickers / navigation
require("plugins.telescope").setup()
require("plugins.flash").setup()
require("plugins.illuminate").setup()
require("plugins.grug-far").setup()

-- UI
require("plugins.theme").setup()
require("plugins.whichkey").setup()
require("plugins.noice").setup()
require("plugins.trouble").setup()
require("plugins.todo-comments").setup()
require("plugins.indent").setup()
require("plugins.lualine").setup()
require("plugins.bufferline").setup()
require("plugins.scope").setup()
require("plugins.neotree").setup()
require("plugins.auto-session").setup()

-- Editing QoL
require("plugins.surround").setup()
require("plugins.autopairs").setup()
require("plugins.rainbow").setup()
require("plugins.guess-indent").setup()
require("plugins.better-escape").setup()
require("plugins.visual-multi").setup()
require("plugins.lazydev").setup()
