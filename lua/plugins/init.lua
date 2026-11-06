---Explicit, ordered plugin setup. Each module configures one plugin (or one
---tight cluster), owns that plugin's keymaps, and declares the plugins it
---needs in `M.spec` (collected by lua/config/pack.lua before any setup runs).
---Subsystems that consume language-pack data expose an apply() called later
---by require("langs").setup().
---@class PluginsIndex
local M = {}

---Setup order; a module is listed once.
M.modules = {
  -- Core editing/IDE subsystems
  "mason",
  "treesitter",
  "lsp",
  "folding",
  "lightbulb",
  "lspsaga",
  "blink",
  "lsp-markdown-fix",
  "render-markdown",
  "conform",
  "lint",
  "dap",
  "overseer",
  "neotest",
  "toggleterm",

  -- AI
  "copilot",
  "sidekick",
  "commitsmith",
  "agentdiff",

  -- Git
  "gitsigns",
  "lazygit",
  "diffview",
  "neogit",
  "octo",
  "git-conflict",

  -- Pickers / navigation
  "telescope",
  "flash",
  "illuminate",
  "grug-far",

  -- UI
  "theme",
  "snacks",
  "whichkey",
  "noice",
  "trouble",
  "todo-comments",
  "indent",
  "lualine",
  "bufferline",
  "barbecue",
  "scope",
  "neotree",
  "oil",
  "auto-session",
  "worktrees",

  -- Editing QoL
  "surround",
  "autopairs",
  "rainbow",
  "guess-indent",
  "better-escape",
  "visual-multi",
  "lazydev",
}

---Every module's install specs, in setup order.
---@return (string|PackSpec)[]
function M.specs()
  local specs = {}
  for _, name in ipairs(M.modules) do
    vim.list_extend(specs, require("plugins." .. name).spec or {})
  end
  return specs
end

function M.setup()
  for _, name in ipairs(M.modules) do
    require("plugins." .. name).setup()
  end
end

return M
