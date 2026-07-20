---which-key.nvim: discoverable keymaps with named leader groups.
---@class PluginWhichKey
local M = {}

function M.setup()
  local wk = require("which-key")
  wk.setup({
    preset = "modern",
  })

  wk.add({
    { "<leader>a", group = "ai" },
    { "<leader>b", group = "buffers" },
    { "<leader>c", group = "code" },
    { "<leader>d", group = "debug" },
    { "<leader>f", group = "find" },
    { "<leader>g", group = "git" },
    { "<leader>gd", group = "diffview" },
    { "<leader>gC", group = "conflict" },
    { "<leader>gh", group = "github" },
    { "<leader>ghi", group = "issues" },
    { "<leader>ghp", group = "pull requests" },
    { "<leader>ghr", group = "reviews" },
    { "<leader>ghc", group = "comments" },
    { "<leader>ghR", group = "reactions" },
    { "<leader>gha", group = "assignees" },
    { "<leader>ghl", group = "labels" },
    { "<leader>ghv", group = "reviewers" },
    { "<leader>j", group = "tabs" },
    { "<leader>k", group = "trouble" },
    { "<leader>l", group = "lsp" },
    { "<leader>lc", group = "codelens" },
    { "<leader>ld", group = "diagnostics" },
    { "<leader>lh", group = "calls" },
    { "<leader>lw", group = "workspace" },
    { "<leader>o", group = "tasks" },
    { "<leader>p", group = "plugins" },
    { "<leader>q", group = "session" },
    { "<leader>s", group = "search/replace" },
    { "<leader>T", group = "terminal" },
    { "<leader>u", group = "ui/toggles" },
    { "<leader>x", group = "close" },
  })
end

return M
