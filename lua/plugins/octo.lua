---octo.nvim: GitHub PRs and issues inside Neovim (requires the gh CLI).
---Pinned to an old commit in config/pack.lua — newer versions are bugged.
---Keymaps live under the <leader>gh GitHub tree, ported from the old config
---(minus its Snacks-based maps).
---@class PluginOcto
local M = {}

function M.setup()
  require("octo").setup({
    picker = "telescope",
    enable_builtin = true,
  })

  -- octo defines its Octo* highlight groups once, inside setup(), and this
  -- pinned version has no ColorScheme hook. Any later `:colorscheme` (Themery,
  -- including its livePreview) runs `hi clear`, which empties those groups and
  -- leaves PR/issue buffers uncolored.
  --
  -- Re-running octo's colors.setup() is not enough on its own: it guards every
  -- group with `hlexists()`, and a cleared group still "exists", so it skips
  -- them all. Stub hlexists() for the duration of the call so the groups are
  -- rebuilt against the new theme (links re-resolve, and the float-derived
  -- backgrounds such as OctoEditable pick up the new colors).
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("config.octo.colors", { clear = true }),
    callback = function()
      local ok, colors = pcall(require, "octo.ui.colors")
      if not ok then
        return
      end
      vim.fn.hlexists = function()
        return 0
      end
      pcall(colors.setup)
      vim.fn.hlexists = nil -- restore the builtin via vim.fn's metatable
    end,
  })

  local map = vim.keymap.set

  -- Issues
  map("n", "<leader>ghil", "<cmd>Octo issue list<cr>", { desc = "List issues" })
  map("n", "<leader>ghic", "<cmd>Octo issue create<cr>", { desc = "Create issue" })
  map("n", "<leader>ghis", "<cmd>Octo issue search<cr>", { desc = "Search issues" })
  map("n", "<leader>ghio", function()
    vim.ui.input({ prompt = "Issue number: " }, function(num)
      if num then
        vim.cmd("Octo issue edit " .. num)
      end
    end)
  end, { desc = "Open/edit issue" })
  map("n", "<leader>ghiC", "<cmd>Octo issue close<cr>", { desc = "Close current issue" })
  map("n", "<leader>ghir", "<cmd>Octo issue reopen<cr>", { desc = "Reopen issue" })
  map("n", "<leader>ghiu", "<cmd>Octo issue url<cr>", { desc = "Copy issue URL" })

  -- Pull requests
  map("n", "<leader>ghpl", "<cmd>Octo pr list<cr>", { desc = "List PRs" })
  map("n", "<leader>ghpc", "<cmd>Octo pr create<cr>", { desc = "Create PR" })
  map("n", "<leader>ghps", "<cmd>Octo pr search<cr>", { desc = "Search PRs" })
  map("n", "<leader>ghpo", function()
    vim.ui.input({ prompt = "PR number: " }, function(num)
      if num then
        vim.cmd("Octo pr edit " .. num)
      end
    end)
  end, { desc = "Open/edit PR" })
  map("n", "<leader>ghpC", "<cmd>Octo pr close<cr>", { desc = "Close PR" })
  map("n", "<leader>ghpm", "<cmd>Octo pr merge<cr>", { desc = "Merge PR" })
  map("n", "<leader>ghpr", "<cmd>Octo pr reload<cr>", { desc = "Reload PR" })
  map("n", "<leader>ghpu", "<cmd>Octo pr url<cr>", { desc = "Copy PR URL" })
  map("n", "<leader>ghpR", "<cmd>Octo pr ready<cr>", { desc = "Mark PR as ready" })
  map("n", "<leader>ghpD", "<cmd>Octo pr draft<cr>", { desc = "Mark PR as draft" })
  map("n", "<leader>ghpv", "<cmd>Octo pr checks<cr>", { desc = "View PR checks" })

  -- Reviews
  map("n", "<leader>ghrs", "<cmd>Octo review start<cr>", { desc = "Start review" })
  map("n", "<leader>ghrr", "<cmd>Octo review resume<cr>", { desc = "Resume review" })
  map("n", "<leader>ghrc", "<cmd>Octo review commit<cr>", { desc = "Pick commit to review" })
  map("n", "<leader>ghrd", "<cmd>Octo review discard<cr>", { desc = "Discard review" })
  map("n", "<leader>ghrS", "<cmd>Octo review submit<cr>", { desc = "Submit review" })
  map("n", "<leader>ghrC", "<cmd>Octo review comments<cr>", { desc = "View review comments" })

  -- Comments
  map("n", "<leader>ghca", "<cmd>Octo comment add<cr>", { desc = "Add comment" })
  map("n", "<leader>ghcd", "<cmd>Octo comment delete<cr>", { desc = "Delete comment" })

  -- Reactions
  map("n", "<leader>ghR+", "<cmd>Octo reaction thumbs_up<cr>", { desc = "Thumbs up" })
  map("n", "<leader>ghR-", "<cmd>Octo reaction thumbs_down<cr>", { desc = "Thumbs down" })
  map("n", "<leader>ghRe", "<cmd>Octo reaction eyes<cr>", { desc = "Eyes" })
  map("n", "<leader>ghRl", "<cmd>Octo reaction laugh<cr>", { desc = "Laugh" })
  map("n", "<leader>ghRh", "<cmd>Octo reaction hooray<cr>", { desc = "Hooray" })
  map("n", "<leader>ghRc", "<cmd>Octo reaction confused<cr>", { desc = "Confused" })
  map("n", "<leader>ghRr", "<cmd>Octo reaction rocket<cr>", { desc = "Rocket" })
  map("n", "<leader>ghRH", "<cmd>Octo reaction heart<cr>", { desc = "Heart" })

  -- Assignees / labels / reviewers
  map("n", "<leader>ghaa", "<cmd>Octo assignee add<cr>", { desc = "Add assignee" })
  map("n", "<leader>ghar", "<cmd>Octo assignee remove<cr>", { desc = "Remove assignee" })
  map("n", "<leader>ghla", "<cmd>Octo label add<cr>", { desc = "Add label" })
  map("n", "<leader>ghlr", "<cmd>Octo label remove<cr>", { desc = "Remove label" })
  map("n", "<leader>ghlc", "<cmd>Octo label create<cr>", { desc = "Create label" })
  map("n", "<leader>ghva", "<cmd>Octo reviewer add<cr>", { desc = "Add reviewer" })

  -- Other GitHub
  map("n", "<leader>ghn", "<cmd>Octo notification list<cr>", { desc = "Notifications" })
  map("n", "<leader>ghs", "<cmd>Octo search<cr>", { desc = "Search GitHub" })
  map("n", "<leader>ghd", "<cmd>Octo discussion list<cr>", { desc = "Discussions" })
end

return M
