---Sidekick: AI CLI sessions in a split, with a prompt library.
---Commit-message generation lives in lua/commitsmith/ (wired by
---plugins/commitsmith.lua); this module configures Sidekick only.
---@class PluginSidekick
local M = {}

local has_tmux = vim.fn.executable("tmux") == 1

---The interactive commit prompt: handed to a live session, which fetches the
---staged diff with its own tools. Kept in sync with commitsmith's rules by
---commitsmith.prompt, which is the single source for them.
local function commit_prompt()
  return require("commitsmith.prompt").fallback()
end

function M.setup()
  require("sidekick").setup({
    nes = {
      enabled = false,
    },
    cli = {
      watch = true,
      picker = "snacks",
      mux = {
        enabled = has_tmux,
        backend = "tmux",
        create = "terminal",
      },
      win = {
        layout = "right",
        split = {
          width = 84,
          height = 20,
        },
      },
      prompts = {
        commit = commit_prompt,
        review_selection = "Can you review this selected code for issues or improvements?\n{selection}",
      },
    },
  })

  local map = vim.keymap.set
  local cli = require("sidekick.cli")
  map({ "n", "x" }, "<leader>aa", function()
    cli.toggle()
  end, { desc = "Toggle Sidekick CLI" })
  map({ "n", "x", "i", "t" }, "<C-.>", function()
    cli.focus()
  end, { desc = "Focus Sidekick CLI" })
  map("n", "<leader>af", function()
    cli.focus()
  end, { desc = "Focus Sidekick CLI" })
  map("n", "<leader>as", function()
    cli.select()
  end, { desc = "Select Sidekick CLI" })
  map({ "n", "x" }, "<leader>ap", function()
    cli.prompt()
  end, { desc = "AI prompt picker" })
  map({ "n", "x" }, "<leader>ae", function()
    cli.send({ prompt = "explain" })
  end, { desc = "Explain code" })
  map("n", "<leader>ar", function()
    cli.send({ prompt = "review" })
  end, { desc = "Review file" })
  map("x", "<leader>ar", function()
    cli.send({ prompt = "review_selection" })
  end, { desc = "Review selection" })
  map("n", "<leader>ad", function()
    cli.send({ prompt = "diagnostics" })
  end, { desc = "Fix diagnostics" })
  map("n", "<leader>aD", function()
    cli.send({ prompt = "diagnostics_all" })
  end, { desc = "Fix workspace diagnostics" })
end

return M
